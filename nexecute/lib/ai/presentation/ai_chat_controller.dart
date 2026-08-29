import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nexecute/ai/domain/ai_chat_message.dart';
import 'package:nexecute/ai/domain/ai_chat_request.dart';
import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/ai/domain/ai_conversation.dart';
import 'package:nexecute/ai/domain/ai_stream_event.dart';
import 'package:nexecute/ai/repositories/ai_assistant_repository.dart';
import 'package:nexecute/ai/repositories/ai_connection_profile_store.dart';
import 'package:nexecute/ai/repositories/ai_conversation_store.dart';
import 'package:nexecute/ai/repositories/ai_response_handle.dart';
import 'package:uuid/uuid.dart';

class AiChatController extends ChangeNotifier {
  AiChatController({
    required AiAssistantRepository assistantRepository,
    required AiConnectionProfileStore connectionProfileStore,
    required AiConversationStore conversationStore,
    String Function()? idFactory,
    DateTime Function()? clock,
  }) : _assistantRepository = assistantRepository,
       _connectionProfileStore = connectionProfileStore,
       _conversationStore = conversationStore,
       _idFactory = idFactory ?? const Uuid().v4,
       _clock = clock ?? DateTime.now;

  final AiAssistantRepository _assistantRepository;
  final AiConnectionProfileStore _connectionProfileStore;
  final AiConversationStore _conversationStore;
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

  bool isLoading = true;
  bool isGenerating = false;
  AiConnectionProfile? activeProfile;
  List<AiConversation> conversations = const [];
  AiConversation? conversation;
  String? errorMessage;

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
    try {
      activeProfile = await _connectionProfileStore.getActiveProfile();
      conversations = await _conversationStore.getConversations();
      if (conversations.isNotEmpty) {
        final latestConversationId = conversations.first.id;
        conversation = await _conversationStore.getConversation(
          latestConversationId,
        );
        if (conversation != null) {
          await _watchCurrentConversation(latestConversationId);
        }
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
    _conversationsSubscription = _conversationStore.watchConversations().listen(
      (value) {
        conversations = value;
        _notify();
      },
      onError: (Object error) {
        errorMessage = 'Could not synchronize AI conversations: $error';
        _notify();
      },
    );
  }

  Future<void> openConversation(String conversationId) async {
    if (isGenerating) await stopResponse();
    await _conversationSubscription?.cancel();
    _draftAssistant = null;
    errorMessage = null;
    conversation = await _conversationStore.getConversation(conversationId);
    _notify();
    _conversationSubscription = _conversationStore
        .watchConversation(conversationId)
        .listen(
          (value) {
            if (value != null) conversation = value;
            _notify();
          },
          onError: (Object error) {
            errorMessage = 'Could not synchronize this conversation: $error';
            _notify();
          },
        );
  }

  Future<void> startNewConversation() async {
    if (isGenerating) await stopResponse();
    await _conversationSubscription?.cancel();
    conversation = null;
    _draftAssistant = null;
    errorMessage = null;
    _notify();
  }

  Future<void> send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || isGenerating) return;
    final profile = activeProfile;
    if (profile == null) {
      errorMessage = 'Choose an AI connection in Settings first.';
      _notify();
      return;
    }

    try {
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
        );
        conversation = current;
        await _conversationStore.saveConversation(current);
        await _watchCurrentConversation(current.id);
      } else if (current.connectionProfileId != profile.id ||
          current.modelId != profile.modelId) {
        current = current.copyWith(
          connectionProfileId: profile.id,
          modelId: profile.modelId,
          updatedAt: now,
        );
        conversation = current;
        await _conversationStore.saveConversation(current);
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
      await _conversationStore.saveMessage(current.id, userMessage);
      await _beginResponse(profile, requestMessages);
    } catch (error) {
      errorMessage = 'Could not send the message: $error';
      _notify();
    }
  }

  Future<void> retryLastResponse() async {
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

    final failed = current.messages[failedIndex];
    final retained = [...current.messages]..removeAt(failedIndex);
    _reasoningByMessageId.remove(failed.id);
    conversation = current.copyWith(messages: retained);
    _notify();
    try {
      await _conversationStore.deleteMessage(current.id, failed.id);
      await _beginResponse(profile, retained);
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

  Future<void> _beginResponse(
    AiConnectionProfile profile,
    List<AiChatMessage> requestMessages,
  ) async {
    final current = conversation;
    if (current == null) return;
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
      final handle = await _assistantRepository.startResponse(
        AiChatRequest(
          connectionProfile: profile,
          conversationId: current.id,
          systemInstruction:
              profile.systemPrompt.trim().isEmpty
                  ? null
                  : profile.systemPrompt.trim(),
          messages:
              requestMessages
                  .where(
                    (message) => message.status == AiMessageStatus.complete,
                  )
                  .toList(),
        ),
      );
      if (generation != _generation || _generationFinalized) {
        await handle.cancel();
        return;
      }
      _responseHandle = handle;
      _responseSubscription = handle.events.listen(
        (event) => _onStreamEvent(generation, event),
        onError:
            (Object error) => unawaited(
              _finalizeGeneration(
                generation,
                AiMessageStatus.failed,
                'The AI response was interrupted: $error',
              ),
            ),
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
    } catch (error) {
      await _finalizeGeneration(
        generation,
        AiMessageStatus.failed,
        'Could not start the AI response: $error',
      );
    }
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
      case AiResponseFailed(:final message, :final code):
        unawaited(
          _finalizeGeneration(
            generation,
            code == 'cancelled'
                ? AiMessageStatus.cancelled
                : AiMessageStatus.failed,
            message,
          ),
        );
      case AiToolCallRequested():
        // Tool execution is deliberately deferred to the later tools step.
        break;
    }
  }

  Future<void> _finalizeGeneration(
    int generation,
    AiMessageStatus status,
    String? message,
  ) async {
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

    final persisted = draft.copyWith(status: status, errorMessage: message);
    conversation = current.copyWith(
      updatedAt: persisted.createdAt,
      messages: [...current.messages, persisted],
    );
    _draftAssistant = null;
    _notify();
    try {
      await _conversationStore.saveMessage(current.id, persisted);
    } catch (error) {
      errorMessage = 'The response could not be synchronized: $error';
      _notify();
    }
  }

  Future<void> _watchCurrentConversation(String conversationId) async {
    await _conversationSubscription?.cancel();
    _conversationSubscription = _conversationStore
        .watchConversation(conversationId)
        .listen((value) {
          if (value != null) conversation = value;
          _notify();
        });
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
