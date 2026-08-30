import 'package:flutter/foundation.dart';
import 'package:nexecute/ai/presentation/ai_note_event_extraction_controller.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:uuid/uuid.dart';

typedef AiEventCreationSubmitter =
    Future<Event> Function(CreateEventCommand command);

enum AiEventProposalCreationStatus { ready, creating, failed, completed }

class AiEventProposalCreationController extends ChangeNotifier {
  AiEventProposalCreationController({
    required AiEventCreationSubmitter submit,
    String Function()? idFactory,
    DateTime Function()? clock,
  }) : _submit = submit,
       _idFactory = idFactory ?? const Uuid().v4,
       _clock = clock ?? DateTime.now;

  final AiEventCreationSubmitter _submit;
  final String Function() _idFactory;
  final DateTime Function() _clock;
  bool _disposed = false;

  AiEventProposalCreationStatus status = AiEventProposalCreationStatus.ready;
  CreateEventCommand? command;
  Event? createdEvent;
  String? errorMessage;

  Future<void> create({
    required String sourceNoteId,
    required AiEventProposalReviewDraft draft,
  }) async {
    if (status != AiEventProposalCreationStatus.ready || !draft.isComplete) {
      return;
    }
    command = CreateEventCommand(
      creationId: _idFactory(),
      sourceNoteId: sourceNoteId,
      title: draft.title,
      description: draft.description,
      startTime: _combine(
        draft.startDate!,
        draft.isAllDay! ? null : draft.startTime,
      ),
      endTime: _combine(draft.endDate!, draft.isAllDay! ? null : draft.endTime),
      isAllDay: draft.isAllDay!,
      tags: draft.tags,
      reminder: draft.reminder,
      createdAt: _clock(),
    );
    await _submitFrozenCommand();
  }

  Future<void> retry() async {
    if (status != AiEventProposalCreationStatus.failed || command == null) {
      return;
    }
    await _submitFrozenCommand();
  }

  Future<void> _submitFrozenCommand() async {
    final frozenCommand = command!;
    status = AiEventProposalCreationStatus.creating;
    errorMessage = null;
    _notify();

    try {
      createdEvent = await _submit(frozenCommand);
      status = AiEventProposalCreationStatus.completed;
    } catch (_) {
      status = AiEventProposalCreationStatus.failed;
      errorMessage =
          'Event creation could not be confirmed. Retry uses the same event ID, '
          'so it cannot create a duplicate.';
    }
    _notify();
  }

  static DateTime _combine(DateTime date, Duration? time) => DateTime(
    date.year,
    date.month,
    date.day,
    time?.inHours ?? 0,
    time?.inMinutes.remainder(60) ?? 0,
  );

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
