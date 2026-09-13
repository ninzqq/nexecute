import 'package:flutter/foundation.dart';
import 'package:nexecute/ai/application/ai_conversation_note_source.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/repositories/note_repository.dart';
import 'package:uuid/uuid.dart';

typedef AiConversationNoteCreateCallback =
    Future<Quicxec> Function(CreateConversationNoteCommand command);

enum AiConversationNoteCreationStatus { ready, creating, failed, completed }

@immutable
class AiConversationNoteReviewDraft {
  const AiConversationNoteReviewDraft({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  String? get validationMessage {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return 'Enter a note title.';
    if (trimmedTitle.contains('\n') || trimmedTitle.contains('\r')) {
      return 'Use a single-line note title.';
    }
    if (trimmedTitle.length > maxCreateConversationNoteTitleCharacters) {
      return 'Use at most $maxCreateConversationNoteTitleCharacters title characters.';
    }
    if (body.trim().isEmpty) return 'Enter note text.';
    if (body.trim().length > maxCreateConversationNoteBodyCharacters) {
      return 'Use at most $maxCreateConversationNoteBodyCharacters text characters.';
    }
    return null;
  }

  bool get isComplete => validationMessage == null;
}

class AiConversationNoteCreationController extends ChangeNotifier {
  AiConversationNoteCreationController({
    required AiConversationNoteCreateCallback submit,
    String Function()? idFactory,
    DateTime Function()? clock,
  }) : _submit = submit,
       _idFactory = idFactory ?? const Uuid().v4,
       _clock = clock ?? DateTime.now;

  final AiConversationNoteCreateCallback _submit;
  final String Function() _idFactory;
  final DateTime Function() _clock;
  bool _disposed = false;

  AiConversationNoteCreationStatus status =
      AiConversationNoteCreationStatus.ready;
  CreateConversationNoteCommand? command;
  Quicxec? createdNote;
  String? errorMessage;

  Future<void> create({
    required AiConversationNoteSource source,
    required AiConversationNoteReviewDraft draft,
  }) async {
    if (status != AiConversationNoteCreationStatus.ready ||
        !draft.isComplete ||
        !source.isWithinLimit) {
      return;
    }
    try {
      command = CreateConversationNoteCommand(
        creationId: _idFactory(),
        sourceConversationId: source.conversationId,
        sourceMessageIds: [for (final message in source.messages) message.id],
        title: draft.title,
        body: draft.body,
        createdAt: _clock(),
      );
    } on ArgumentError {
      errorMessage = 'Review the note and selected conversation messages.';
      _notify();
      return;
    }
    await _submitFrozenCommand();
  }

  Future<void> retry() async {
    if (status != AiConversationNoteCreationStatus.failed || command == null) {
      return;
    }
    await _submitFrozenCommand();
  }

  Future<void> _submitFrozenCommand() async {
    final frozenCommand = command!;
    status = AiConversationNoteCreationStatus.creating;
    errorMessage = null;
    _notify();

    try {
      createdNote = await _submit(frozenCommand);
      status = AiConversationNoteCreationStatus.completed;
    } catch (_) {
      status = AiConversationNoteCreationStatus.failed;
      errorMessage =
          'Note creation could not be confirmed. Retry uses the same note ID, '
          'so it cannot create a duplicate.';
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
