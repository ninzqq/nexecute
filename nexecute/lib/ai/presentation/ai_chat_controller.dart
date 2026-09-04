import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nexecute/ai/application/ai_prompt_composer.dart';
import 'package:nexecute/ai/application/ai_read_tool_coordinator.dart';
import 'package:nexecute/ai/application/ai_skill_resolver.dart';
import 'package:nexecute/ai/domain/ai_chat_message.dart';
import 'package:nexecute/ai/domain/ai_chat_request.dart';
import 'package:nexecute/ai/domain/ai_application_context.dart';
import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/ai/domain/ai_conversation.dart';
import 'package:nexecute/ai/domain/ai_diagnostic.dart';
import 'package:nexecute/ai/domain/ai_stream_event.dart';
import 'package:nexecute/ai/domain/ai_skill_invocation.dart';
import 'package:nexecute/ai/repositories/ai_assistant_repository.dart';
import 'package:nexecute/ai/repositories/ai_connection_profile_store.dart';
import 'package:nexecute/ai/repositories/ai_conversation_store.dart';
import 'package:nexecute/ai/repositories/ai_response_handle.dart';
import 'package:nexecute/ai/repositories/ai_skill_store.dart';
import 'package:uuid/uuid.dart';

enum AiSkillActivationScope { conversation, nextRequest }

enum AiSkillMismatchAction { block, continueWithoutSkills }

class AiChatController extends ChangeNotifier {
  AiChatController({
    required AiAssistantRepository assistantRepository,
    required AiConnectionProfileStore connectionProfileStore,
    required AiConversationStore conversationStore,
    AiSkillStore? skillStore,
    AiPromptComposer promptComposer = const AiPromptComposer(),
    AiReadToolCoordinator? readToolCoordinator,
    String Function()? idFactory,
    DateTime Function()? clock,
  }) : _assistantRepository = assistantRepository,
       _connectionProfileStore = connectionProfileStore,
       _conversationStore = conversationStore,
       _skillResolver =
           skillStore == null ? null : AiSkillResolver(store: skillStore),
       _promptComposer = promptComposer,
       _readToolCoordinator = readToolCoordinator,
       _idFactory = idFactory ?? const Uuid().v4,
       _clock = clock ?? DateTime.now;

  final AiAssistantRepository _assistantRepository;
  final AiConnectionProfileStore _connectionProfileStore;
  final AiConversationStore _conversationStore;
  final AiSkillResolver? _skillResolver;
  final AiPromptComposer _promptComposer;
  final AiReadToolCoordinator? _readToolCoordinator;
  final String Function() _idFactory;
  final DateTime Function() _clock;

  StreamSubscription<AiConnectionProfile?>? _profileSubscription;
  StreamSubscription<List<AiConversation>>? _conversationsSubscription;
  StreamSubscription<AiConversation?>? _conversationSubscription;
  StreamSubscription<AiStreamEvent>? _responseSubscription;
  AiResponseHandle? _responseHandle;
  AiChatMessage? _draftAssistant;
  final Map<String, String> _reasoningByMessageId = {};
  bool _generationFinalized = true;
  int _generation = 0;
  bool _disposed = false;
  List<AiSkillReference> _newConversationSkills = const [];
  List<AiSkillReference>? _nextRequestSkills;

  bool isLoading = true;
  bool isGenerating = false;
  AiConnectionProfile? activeProfile;
  List<AiConversation> conversations = const [];
  AiConversation? conversation;
  String? errorMessage;
  AiSkillResolutionException? skillResolutionError;

  List<AiSkillReference> get conversationSkills =>
      conversation?.activeSkills ?? _newConversationSkills;

  List<AiSkillReference>? get nextRequestSkills => _nextRequestSkills;

  List<AiSkillReference> get effectiveSkills =>
      _nextRequestSkills ?? conversationSkills;

  List<AiChatMessage> get messages => List.unmodifiable([
    ...?conversation?.messages,
    if (_draftAssistant case final draft?) draft,
  ]);

  String? reasoningForMessage(String messageId) {
    final reasoning = _reasoningByMessageId[messageId];
    return reasoning == null || reasoning.isEmpty ? null : reasoning;
  }

  bool get canRetry =>
      !isGenerating &&
      (conversation?.messages.any(
            (message) =>
                message.role == AiMessageRole.assistant &&
                (message.status == AiMessageStatus.failed ||
                    message.status == AiMessageStatus.cancelled),
          ) ??
          false);

  Future<void> initialize() async {
    final initialConversations = Completer<List<AiConversation>>();
    try {
      activeProfile = await _connectionProfileStore.getActiveProfile();
      _conversationsSubscription = _conversationStore
          .watchConversations()
          .listen(
            (value) {
              conversations = value;
              _notify();
              if (!initialConversations.isCompleted) {
                initialConversations.complete(value);
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              errorMessage = 'Could not synchronize AI conversations: $error';
              _notify();
              if (!initialConversations.isCompleted) {
                initialConversations.completeError(error, stackTrace);
              }
            },
          );
      final initial = await initialConversations.future;
      if (initial.isNotEmpty) {
        final latestConversationId = initial.first.id;
        await _watchCurrentConversation(latestConversationId);
      }
    } catch (error) {
      errorMessage = 'Could not load AI conversations: $error';
    } finally {
      isLoading = false;
      _notify();
    }

    _profileSubscription = _connectionProfileStore.watchActiveProfile().listen(
      (profile) {
        activeProfile = profile;
        _notify();
      },
      onError: (Object error) {
        errorMessage = 'Could not load the active AI connection: $error';
        _notify();
      },
    );
  }

  Future<void> openConversation(String conversationId) async {
    if (isGenerating) await stopResponse();
    _draftAssistant = null;
    errorMessage = null;
    skillResolutionError = null;
    _nextRequestSkills = null;
    _newConversationSkills = const [];
    await _watchCurrentConversation(conversationId);
  }

  Future<void> startNewConversation() async {
    if (isGenerating) await stopResponse();
    await _conversationSubscription?.cancel();
    conversation = null;
    _draftAssistant = null;
    errorMessage = null;
    skillResolutionError = null;
    _nextRequestSkills = null;
    _newConversationSkills = const [];
    _notify();
  }

  Future<bool> setActiveSkills(
    Iterable<AiSkillReference> references, {
    AiSkillActivationScope scope = AiSkillActivationScope.conversation,
  }) async {
    if (isGenerating) return false;
    final normalized = normalizeAiSkillReferences(references);
    skillResolutionError = null;
    errorMessage = null;
    if (scope == AiSkillActivationScope.nextRequest) {
      _nextRequestSkills = normalized;
      _notify();
      return true;
    }

    final current = conversation;
    if (current == null) {
      _newConversationSkills = normalized;
      _notify();
      return true;
    }
    final updated = current.copyWith(
      activeSkills: normalized,
      updatedAt: _nextMessageTime(),
    );
    conversation = updated;
    _notify();
    _persistInBackground(
      _conversationStore.saveConversation(updated),
      failureMessage: 'The active skills could not be synchronized',
    );
    return true;
  }

  Future<bool> send(
    String rawText, {
    AiApplicationContextEnvelope? applicationContext,
    AiReadToolExecutionScope? readToolExecutionScope,
    AiSkillMismatchAction skillMismatchAction = AiSkillMismatchAction.block,
  }) async {
    final text = rawText.trim();
    if (text.isEmpty || isGenerating) return false;
    final profile = activeProfile;
    if (profile == null) {
      errorMessage = 'Choose an AI connection in Settings first.';
      _notify();
      return false;
    }

    try {
      final resolvedSkills = await _resolveSkills(
        effectiveSkills,
        mismatchAction: skillMismatchAction,
      );
      _nextRequestSkills = null;
      var current = conversation;
      final now = _nextMessageTime();
      if (current == null) {
        current = AiConversation(
          id: _idFactory(),
          title: _titleFor(text),
          connectionProfileId: profile.id,
          modelId: profile.modelId,
          createdAt: now,
          updatedAt: now,
          activeSkills: _newConversationSkills,
        );
        _newConversationSkills = const [];
        conversation = current;
        final conversationId = current.id;
        _persistInBackground(
          _conversationStore.saveConversation(current),
          failureMessage: 'The conversation could not be synchronized',
          afterSynchronization: () async {
            if (conversation?.id == conversationId) {
              await _watchCurrentConversation(conversationId);
            }
          },
        );
      } else if (current.connectionProfileId != profile.id ||
          current.modelId != profile.modelId) {
        current = current.copyWith(
          connectionProfileId: profile.id,
          modelId: profile.modelId,
          updatedAt: now,
        );
        conversation = current;
        _persistInBackground(
          _conversationStore.saveConversation(current),
          failureMessage: 'The conversation could not be synchronized',
        );
      }

      final userMessage = AiChatMessage(
        id: _idFactory(),
        role: AiMessageRole.user,
        content: text,
        createdAt: now,
      );
      final requestMessages = [...current.messages, userMessage];
      conversation = current.copyWith(
        updatedAt: now,
        messages: requestMessages,
      );
      errorMessage = null;
      _notify();
      _persistInBackground(
        _conversationStore.saveMessage(current.id, userMessage),
        failureMessage: 'The message could not be synchronized',
      );
      return await _beginResponse(
        profile,
        requestMessages,
        applicationContext: applicationContext,
        readToolExecutionScope: readToolExecutionScope,
        resolvedSkills: resolvedSkills,
      );
    } on AiSkillResolutionException catch (error) {
      skillResolutionError = error;
      errorMessage = _skillResolutionMessage(error);
      _notify();
      return false;
    } catch (error) {
      errorMessage = 'Could not send the message: $error';
      _notify();
      return false;
    }
  }

  Future<void> retryLastResponse({
    AiSkillMismatchAction skillMismatchAction = AiSkillMismatchAction.block,
  }) async {
    if (isGenerating) return;
    final profile = activeProfile;
    final current = conversation;
    if (profile == null || current == null) return;
    final failedIndex = current.messages.lastIndexWhere(
      (message) =>
          message.role == AiMessageRole.assistant &&
          (message.status == AiMessageStatus.failed ||
              message.status == AiMessageStatus.cancelled),
    );
    if (failedIndex < 0) return;

    try {
      final resolvedSkills = await _resolveSkills(
        effectiveSkills,
        mismatchAction: skillMismatchAction,
      );
      _nextRequestSkills = null;
      final failed = current.messages[failedIndex];
      final retained = [...current.messages]..removeAt(failedIndex);
      _reasoningByMessageId.remove(failed.id);
      conversation = current.copyWith(messages: retained);
      _notify();
      _persistInBackground(
        _conversationStore.deleteMessage(current.id, failed.id),
        failureMessage: 'The failed response could not be removed',
      );
      await _beginResponse(profile, retained, resolvedSkills: resolvedSkills);
    } on AiSkillResolutionException catch (error) {
      skillResolutionError = error;
      errorMessage = _skillResolutionMessage(error);
      _notify();
    } catch (error) {
      errorMessage = 'Could not retry the response: $error';
      _notify();
    }
  }

  Future<void> stopResponse() async {
    if (!isGenerating) return;
    final generation = _generation;
    await _responseHandle?.cancel();
    await _finalizeGeneration(
      generation,
      AiMessageStatus.cancelled,
      'Response stopped.',
    );
  }

  Future<void> deleteConversation(String conversationId) async {
    if (conversation?.id == conversationId) await startNewConversation();
    await _conversationStore.deleteConversation(conversationId);
  }

  void clearError() {
    errorMessage = null;
    _notify();
  }

  Future<bool> _beginResponse(
    AiConnectionProfile profile,
    List<AiChatMessage> requestMessages, {
    AiApplicationContextEnvelope? applicationContext,
    AiReadToolExecutionScope? readToolExecutionScope,
    List<AiResolvedSkillInvocation> resolvedSkills = const [],
  }) async {
    final current = conversation;
    if (current == null) return false;
    final generation = ++_generation;
    _generationFinalized = false;
    _draftAssistant = AiChatMessage(
      id: _idFactory(),
      role: AiMessageRole.assistant,
      content: '',
      createdAt: _nextMessageTime(),
      status: AiMessageStatus.streaming,
    );
    isGenerating = true;
    _notify();

    try {
      final request = AiChatRequest(
        connectionProfile: profile,
        conversationId: current.id,
        systemInstruction: _promptComposer.compose(
          profilePreferences: profile.systemPrompt,
          resolvedSkills: resolvedSkills,
        ),
        resolvedSkills: resolvedSkills,
        messages:
            requestMessages
                .where((message) => message.status == AiMessageStatus.complete)
                .toList(),
        applicationContext: applicationContext,
        readToolAuthorization:
            _readToolCoordinator == null
                ? null
                : readToolExecutionScope?.authorization,
      );
      final handle =
          _readToolCoordinator != null && readToolExecutionScope != null
              ? await _readToolCoordinator.startResponse(
                request,
                scope: readToolExecutionScope,
              )
              : await _assistantRepository.startResponse(request);
      if (generation != _generation || _generationFinalized) {
        await handle.cancel();
        return false;
      }
      _responseHandle = handle;
      _responseSubscription = handle.events.listen(
        (event) => _onStreamEvent(generation, event),
        onError: (Object error) {
          final diagnostic =
              error is AiDiagnosticException ? error.diagnostic : null;
          unawaited(
            _finalizeGeneration(
              generation,
              AiMessageStatus.failed,
              diagnostic?.summary ?? 'The AI response was interrupted.',
              diagnostic: diagnostic,
            ),
          );
        },
        onDone: () {
          if (!_generationFinalized) {
            unawaited(
              _finalizeGeneration(
                generation,
                AiMessageStatus.failed,
                'The AI response ended unexpectedly.',
              ),
            );
          }
        },
      );
      return true;
    } on AiDiagnosticException catch (error) {
      await _finalizeGeneration(
        generation,
        AiMessageStatus.failed,
        error.message,
        diagnostic: error.diagnostic,
      );
      return false;
    } catch (_) {
      await _finalizeGeneration(
        generation,
        AiMessageStatus.failed,
        'Could not start the AI response.',
      );
      return false;
    }
  }

  Future<List<AiResolvedSkillInvocation>> _resolveSkills(
    List<AiSkillReference> references, {
    required AiSkillMismatchAction mismatchAction,
  }) async {
    if (references.isEmpty) {
      skillResolutionError = null;
      return const [];
    }
    try {
      final resolver = _skillResolver;
      if (resolver == null) {
        throw AiSkillResolutionException([
          for (final reference in references)
            AiSkillResolutionIssue(
              reference: reference,
              kind: AiSkillResolutionIssueKind.storageUnavailable,
            ),
        ]);
      }
      final resolved = await resolver.resolve(references);
      skillResolutionError = null;
      return resolved;
    } on AiSkillResolutionException {
      if (mismatchAction == AiSkillMismatchAction.continueWithoutSkills) {
        skillResolutionError = null;
        return const [];
      }
      rethrow;
    }
  }

  static String _skillResolutionMessage(AiSkillResolutionException error) {
    final ids = error.issues.map((issue) => issue.reference.id).join(', ');
    return 'Active skills require attention before sending: $ids. '
        'Replace or import them, or explicitly continue without skills.';
  }

  void _onStreamEvent(int generation, AiStreamEvent event) {
    if (generation != _generation || _generationFinalized) return;
    switch (event) {
      case AiReasoningDelta(:final text):
        final draft = _draftAssistant;
        if (draft == null) return;
        _reasoningByMessageId.update(
          draft.id,
          (reasoning) => '$reasoning$text',
          ifAbsent: () => text,
        );
        _notify();
      case AiTextDelta(:final text):
        final draft = _draftAssistant;
        if (draft == null) return;
        _draftAssistant = draft.copyWith(content: '${draft.content}$text');
        _notify();
      case AiResponseCompleted():
        unawaited(
          _finalizeGeneration(generation, AiMessageStatus.complete, null),
        );
      case AiResponseFailed(:final message, :final code, :final diagnostic):
        unawaited(
          _finalizeGeneration(
            generation,
            code == 'cancelled'
                ? AiMessageStatus.cancelled
                : AiMessageStatus.failed,
            message,
            diagnostic: diagnostic,
          ),
        );
      case AiToolCallRequested():
        unawaited(_responseHandle?.cancel());
        unawaited(
          _finalizeGeneration(
            generation,
            AiMessageStatus.failed,
            'The AI requested an unauthorized tool call.',
          ),
        );
    }
  }

  Future<void> _finalizeGeneration(
    int generation,
    AiMessageStatus status,
    String? message, {
    AiDiagnostic? diagnostic,
  }) async {
    if (generation != _generation || _generationFinalized) return;
    _generationFinalized = true;
    final draft = _draftAssistant;
    final current = conversation;
    isGenerating = false;
    _responseHandle = null;
    if (draft == null || current == null) {
      _draftAssistant = null;
      _notify();
      return;
    }

    final persisted = draft.copyWith(
      status: status,
      errorMessage: message,
      diagnostic: diagnostic,
    );
    conversation = current.copyWith(
      updatedAt: persisted.createdAt,
      messages: [...current.messages, persisted],
    );
    _draftAssistant = null;
    _notify();
    _persistInBackground(
      _conversationStore.saveMessage(current.id, persisted),
      failureMessage: 'The response could not be synchronized',
    );
  }

  Future<void> _watchCurrentConversation(String conversationId) async {
    await _conversationSubscription?.cancel();
    final completer = Completer<void>();
    _conversationSubscription = _conversationStore
        .watchConversation(conversationId)
        .listen(
          (value) {
            conversation = value;
            _notify();
            if (!completer.isCompleted) completer.complete();
          },
          onError: (Object error) {
            errorMessage = 'Could not synchronize this conversation: $error';
            _notify();
            if (!completer.isCompleted) completer.complete();
          },
        );
    await completer.future;
  }

  void _persistInBackground(
    Future<void> operation, {
    required String failureMessage,
    Future<void> Function()? afterSynchronization,
  }) {
    unawaited(() async {
      try {
        await operation;
        await afterSynchronization?.call();
      } catch (error) {
        errorMessage = '$failureMessage: $error';
        _notify();
      }
    }());
  }

  DateTime _nextMessageTime() {
    final value = _clock();
    final last = messages.isEmpty ? null : messages.last.createdAt;
    return last != null && !value.isAfter(last)
        ? last.add(const Duration(microseconds: 1))
        : value;
  }

  static String _titleFor(String text) {
    final oneLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (oneLine.length <= 48) return oneLine;
    return '${oneLine.substring(0, 47)}…';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_profileSubscription?.cancel());
    unawaited(_conversationsSubscription?.cancel());
    unawaited(_conversationSubscription?.cancel());
    unawaited(_responseSubscription?.cancel());
    if (isGenerating) unawaited(_responseHandle?.cancel());
    super.dispose();
  }
}
