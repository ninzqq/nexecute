import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nexecute/ai/application/ai_note_task_prompt.dart';
import 'package:nexecute/ai/domain/ai_chat_message.dart';
import 'package:nexecute/ai/domain/ai_chat_request.dart';
import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/ai/domain/ai_stream_event.dart';
import 'package:nexecute/ai/domain/ai_task_proposal.dart';
import 'package:nexecute/ai/infrastructure/ai_task_proposal_parser.dart';
import 'package:nexecute/ai/repositories/ai_assistant_repository.dart';
import 'package:nexecute/ai/repositories/ai_connection_profile_store.dart';
import 'package:nexecute/ai/repositories/ai_response_handle.dart';
import 'package:uuid/uuid.dart';

enum AiNoteTaskExtractionStatus {
  loading,
  ready,
  generating,
  completed,
  cancelled,
  failed,
}

class AiNoteTaskExtractionController extends ChangeNotifier {
  AiNoteTaskExtractionController({
    required AiAssistantRepository assistantRepository,
    required AiConnectionProfileStore connectionProfileStore,
    String Function()? idFactory,
  }) : _assistantRepository = assistantRepository,
       _connectionProfileStore = connectionProfileStore,
       _idFactory = idFactory ?? const Uuid().v4;

  final AiAssistantRepository _assistantRepository;
  final AiConnectionProfileStore _connectionProfileStore;
  final String Function() _idFactory;

  AiResponseHandle? _handle;
  StreamSubscription<AiStreamEvent>? _subscription;
  bool _finalized = true;
  bool _disposed = false;

  AiNoteTaskExtractionStatus status = AiNoteTaskExtractionStatus.loading;
  AiConnectionProfile? activeProfile;
  AiTaskProposal? proposal;
  String? errorMessage;

  Future<void> initialize() async {
    try {
      activeProfile = await _connectionProfileStore.getActiveProfile();
      status = AiNoteTaskExtractionStatus.ready;
      if (activeProfile == null) {
        errorMessage = 'Select an AI connection in Settings first.';
      }
    } catch (_) {
      status = AiNoteTaskExtractionStatus.failed;
      errorMessage = 'Could not load the active AI connection.';
    }
    _notify();
  }

  Future<void> start({
    required String noteId,
    required String noteTitle,
    required String noteContent,
  }) async {
    if (status == AiNoteTaskExtractionStatus.generating) return;
    final profile = activeProfile;
    if (profile == null) return;

    final AiNoteTaskPrompt prompt;
    try {
      prompt = AiNoteTaskPromptBuilder.build(
        noteTitle: noteTitle,
        noteContent: noteContent,
      );
    } on ArgumentError catch (error) {
      status = AiNoteTaskExtractionStatus.failed;
      errorMessage = error.message?.toString() ?? 'The note is too large.';
      _notify();
      return;
    }

    status = AiNoteTaskExtractionStatus.generating;
    proposal = null;
    errorMessage = null;
    _finalized = false;
    _notify();

    try {
      final handle = await _assistantRepository.startResponse(
        AiChatRequest(
          connectionProfile: profile,
          conversationId: 'note-task-extraction:$noteId',
          systemInstruction: prompt.systemInstruction,
          messages: [
            AiChatMessage(
              id: _idFactory(),
              role: AiMessageRole.user,
              content: prompt.userMessage,
              createdAt: DateTime.now(),
            ),
          ],
        ),
      );
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
              output.write(text);
            case AiReasoningDelta():
              break;
            case AiResponseCompleted():
              _complete(output.toString());
            case AiResponseFailed(:final message, :final code):
              _finish(
                code == 'cancelled'
                    ? AiNoteTaskExtractionStatus.cancelled
                    : AiNoteTaskExtractionStatus.failed,
                message,
              );
            case AiToolCallRequested():
              _finish(
                AiNoteTaskExtractionStatus.failed,
                'The model returned a tool call instead of task proposals.',
              );
          }
        },
        onError:
            (_) => _finish(
              AiNoteTaskExtractionStatus.failed,
              'The AI response was interrupted.',
            ),
        onDone: () {
          if (!_finalized) {
            _finish(
              AiNoteTaskExtractionStatus.failed,
              'The AI response ended before completing the proposal.',
            );
          }
        },
      );
    } catch (_) {
      _finish(
        AiNoteTaskExtractionStatus.failed,
        'Could not start task extraction.',
      );
    }
  }

  Future<void> cancel() async {
    if (status != AiNoteTaskExtractionStatus.generating) return;
    _finalized = true;
    await _subscription?.cancel();
    await _handle?.cancel();
    _subscription = null;
    _handle = null;
    status = AiNoteTaskExtractionStatus.cancelled;
    errorMessage = 'Task extraction was cancelled.';
    _notify();
  }

  void _complete(String output) {
    try {
      proposal = AiTaskProposalParser.parse(output);
      _finish(AiNoteTaskExtractionStatus.completed, null);
    } on AiTaskProposalFormatException catch (error) {
      _finish(AiNoteTaskExtractionStatus.failed, error.message);
    }
  }

  void _finish(AiNoteTaskExtractionStatus nextStatus, String? message) {
    if (_finalized) return;
    _finalized = true;
    status = nextStatus;
    errorMessage = message;
    _handle = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _notify();
  }

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
