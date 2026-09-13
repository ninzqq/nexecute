import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nexecute/ai/application/ai_conversation_note_prompt.dart';
import 'package:nexecute/ai/application/ai_conversation_note_source.dart';
import 'package:nexecute/ai/application/ai_request_budget.dart';
import 'package:nexecute/ai/domain/ai_chat_message.dart';
import 'package:nexecute/ai/domain/ai_chat_request.dart';
import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/ai/domain/ai_diagnostic.dart';
import 'package:nexecute/ai/domain/ai_note_proposal.dart';
import 'package:nexecute/ai/domain/ai_stream_event.dart';
import 'package:nexecute/ai/infrastructure/ai_connection_profile_codec.dart';
import 'package:nexecute/ai/infrastructure/ai_note_proposal_parser.dart';
import 'package:nexecute/ai/repositories/ai_assistant_repository.dart';
import 'package:nexecute/ai/repositories/ai_connection_profile_store.dart';
import 'package:nexecute/ai/repositories/ai_response_handle.dart';
import 'package:uuid/uuid.dart';

enum AiConversationNoteGenerationStatus {
  ready,
  generating,
  completed,
  cancelled,
  failed,
}

class AiConversationNoteGenerationController extends ChangeNotifier {
  AiConversationNoteGenerationController({
    required AiAssistantRepository assistantRepository,
    required AiConnectionProfileStore connectionProfileStore,
    required AiConnectionProfile previewedProfile,
    String Function()? idFactory,
    DateTime Function()? clock,
  }) : _assistantRepository = assistantRepository,
       _connectionProfileStore = connectionProfileStore,
       _previewedProfile = previewedProfile,
       _idFactory = idFactory ?? const Uuid().v4,
       _clock = clock ?? DateTime.now;

  final AiAssistantRepository _assistantRepository;
  final AiConnectionProfileStore _connectionProfileStore;
  final AiConnectionProfile _previewedProfile;
  final String Function() _idFactory;
  final DateTime Function() _clock;

  AiResponseHandle? _handle;
  StreamSubscription<AiStreamEvent>? _subscription;
  bool _finalized = true;
  bool _disposed = false;

  AiConversationNoteGenerationStatus status =
      AiConversationNoteGenerationStatus.ready;
  AiNoteProposal? proposal;
  String reasoning = '';
  String? errorMessage;
  AiDiagnostic? diagnostic;

  void reset() {
    if (status == AiConversationNoteGenerationStatus.generating) return;
    status = AiConversationNoteGenerationStatus.ready;
    proposal = null;
    reasoning = '';
    errorMessage = null;
    diagnostic = null;
    _notify();
  }

  Future<void> start(AiConversationNoteSource source) async {
    if (status == AiConversationNoteGenerationStatus.generating || _disposed) {
      return;
    }
    final AiConversationNotePrompt prompt;
    try {
      prompt = AiConversationNotePromptBuilder.build(source);
    } on ArgumentError catch (error) {
      _fail(error.message?.toString() ?? 'Select fewer conversation messages.');
      return;
    }

    status = AiConversationNoteGenerationStatus.generating;
    proposal = null;
    reasoning = '';
    errorMessage = null;
    diagnostic = null;
    _finalized = false;
    _notify();

    // Re-read immediately before the request: a changed destination needs a
    // new preview and an explicit new Generate action.
    final AiConnectionProfile? active;
    try {
      active = await _connectionProfileStore.getActiveProfile();
    } catch (_) {
      if (!_finalized && !_disposed) {
        _fail('Could not verify the active AI connection.');
      }
      return;
    }
    if (_finalized || _disposed) return;
    if (active == null || !_sameProfile(active, _previewedProfile)) {
      _fail(
        'The AI connection changed. Close this preview and review it again.',
      );
      return;
    }
    if (!active.canSendRequests(isWeb: kIsWeb)) {
      _fail('The selected AI connection is unavailable on this device.');
      return;
    }

    final request = AiChatRequest(
      connectionProfile: active,
      conversationId: 'conversation-note-proposal:${source.conversationId}',
      systemInstruction: prompt.systemInstruction,
      messages: [
        AiChatMessage(
          id: _idFactory(),
          role: AiMessageRole.user,
          content: prompt.userMessage,
          createdAt: _clock(),
        ),
      ],
    );
    try {
      AiRequestBudget.validate(request);
    } on AiRequestBudgetException catch (error) {
      _fail(error.message);
      return;
    }

    try {
      final handle = await _assistantRepository.startResponse(request);
      if (_finalized || _disposed) {
        await handle.cancel();
        return;
      }
      _handle = handle;
      final output = StringBuffer();
      _subscription = handle.events.listen(
        (event) {
          if (_finalized) return;
          switch (event) {
            case AiTextDelta(:final text):
              if (output.length + text.length >
                  aiMaxNoteProposalResponseCharacters) {
                _finish(
                  AiConversationNoteGenerationStatus.failed,
                  'The model response was too large to be a note proposal.',
                );
                unawaited(handle.cancel());
              } else {
                output.write(text);
              }
            case AiReasoningDelta(:final text):
              if (reasoning.length < 4000) {
                reasoning = '$reasoning$text';
                if (reasoning.length > 4000) {
                  reasoning = reasoning.substring(0, 4000);
                }
                _notify();
              }
            case AiCitationsResolved():
              break;
            case AiResponseCompleted():
              _complete(output.toString());
            case AiResponseFailed(
              :final message,
              :final code,
              :final diagnostic,
            ):
              _finish(
                code == 'cancelled'
                    ? AiConversationNoteGenerationStatus.cancelled
                    : AiConversationNoteGenerationStatus.failed,
                message,
                diagnostic: diagnostic,
              );
            case AiToolCallRequested():
              _finish(
                AiConversationNoteGenerationStatus.failed,
                'The model returned a tool call instead of a note proposal.',
              );
              unawaited(handle.cancel());
          }
        },
        onError:
            (Object error) => _finish(
              AiConversationNoteGenerationStatus.failed,
              error is AiDiagnosticException
                  ? error.message
                  : 'The AI response was interrupted.',
              diagnostic:
                  error is AiDiagnosticException ? error.diagnostic : null,
            ),
        onDone: () {
          if (!_finalized) {
            _finish(
              AiConversationNoteGenerationStatus.failed,
              'The AI response ended before completing the proposal.',
            );
          }
        },
      );
    } on AiDiagnosticException catch (error) {
      _finish(
        AiConversationNoteGenerationStatus.failed,
        error.message,
        diagnostic: error.diagnostic,
      );
    } catch (_) {
      _finish(
        AiConversationNoteGenerationStatus.failed,
        'Could not start note generation.',
      );
    }
  }

  Future<void> cancel() async {
    if (status != AiConversationNoteGenerationStatus.generating) return;
    _finalized = true;
    await _subscription?.cancel();
    await _handle?.cancel();
    _subscription = null;
    _handle = null;
    status = AiConversationNoteGenerationStatus.cancelled;
    errorMessage = 'Note generation was cancelled.';
    diagnostic = null;
    _notify();
  }

  void _complete(String output) {
    try {
      proposal = AiNoteProposalParser.parse(output);
      _finish(AiConversationNoteGenerationStatus.completed, null);
    } on AiNoteProposalFormatException catch (error) {
      _finish(AiConversationNoteGenerationStatus.failed, error.message);
    }
  }

  void _fail(String message) {
    _finalized = true;
    status = AiConversationNoteGenerationStatus.failed;
    proposal = null;
    errorMessage = message;
    diagnostic = null;
    _notify();
  }

  void _finish(
    AiConversationNoteGenerationStatus nextStatus,
    String? message, {
    AiDiagnostic? diagnostic,
  }) {
    if (_finalized) return;
    _finalized = true;
    status = nextStatus;
    errorMessage = message;
    this.diagnostic = diagnostic;
    _handle = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _notify();
  }

  bool _sameProfile(AiConnectionProfile first, AiConnectionProfile second) =>
      jsonEncode(AiConnectionProfileCodec.toMap(first)) ==
      jsonEncode(AiConnectionProfileCodec.toMap(second));

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    if (!_finalized) unawaited(_handle?.cancel());
    super.dispose();
  }
}
