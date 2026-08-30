import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/repositories/event_repository.dart';

void main() {
  test(
    'freezes one event command and retries that exact command safely',
    () async {
      final submissions = <CreateEventCommand>[];
      var shouldFail = true;
      final createdAt = DateTime.utc(2026, 8, 30, 12);
      final controller = AiEventProposalCreationController(
        idFactory: () => 'creation-1',
        clock: () => createdAt,
        submit: (command) async {
          submissions.add(command);
          if (shouldFail) throw StateError('ambiguous write failure');
          return command.toEvent();
        },
      );
      addTearDown(controller.dispose);

      await controller.create(sourceNoteId: 'note-1', draft: _draft());

      expect(controller.status, AiEventProposalCreationStatus.failed);
      expect(controller.command?.creationId, 'creation-1');
      expect(controller.command?.eventId, 'ai-event-creation-1');
      expect(controller.command?.sourceNoteId, 'note-1');
      expect(controller.command?.title, 'Dentist');
      expect(controller.command?.startTime, DateTime(2026, 9, 3, 14));
      expect(controller.command?.createdAt, createdAt);
      expect(submissions, hasLength(1));

      shouldFail = false;
      await controller.retry();

      expect(controller.status, AiEventProposalCreationStatus.completed);
      expect(controller.createdEvent?.id, 'ai-event-creation-1');
      expect(submissions, hasLength(2));
      expect(identical(submissions[0], submissions[1]), isTrue);

      await controller.create(sourceNoteId: 'note-2', draft: _draft());
      await controller.retry();
      expect(submissions, hasLength(2));
    },
  );

  test('prevents repeated submission while creation is in progress', () async {
    final completion = Completer<Event>();
    final submissions = <CreateEventCommand>[];
    final controller = AiEventProposalCreationController(
      idFactory: () => 'creation-1',
      submit: (command) {
        submissions.add(command);
        return completion.future;
      },
    );
    addTearDown(controller.dispose);

    final creation = controller.create(sourceNoteId: 'note-1', draft: _draft());
    expect(controller.status, AiEventProposalCreationStatus.creating);

    await controller.create(sourceNoteId: 'note-2', draft: _draft());
    await controller.retry();
    expect(submissions, hasLength(1));

    completion.complete(submissions.single.toEvent());
    await creation;
    expect(controller.status, AiEventProposalCreationStatus.completed);
    expect(submissions, hasLength(1));
  });

  test('converts an all-day inclusive range to local date endpoints', () async {
    CreateEventCommand? submitted;
    final controller = AiEventProposalCreationController(
      idFactory: () => 'creation-1',
      submit: (command) async {
        submitted = command;
        return command.toEvent();
      },
    );
    addTearDown(controller.dispose);

    await controller.create(
      sourceNoteId: 'note-1',
      draft: _draft(
        startDate: DateTime(2026, 9, 3),
        endDate: DateTime(2026, 9, 5),
        isAllDay: true,
        startTime: null,
        endTime: null,
      ),
    );

    expect(submitted?.startTime, DateTime(2026, 9, 3));
    expect(submitted?.endTime, DateTime(2026, 9, 5));
    expect(submitted?.isAllDay, isTrue);
  });
}

AiEventProposalReviewDraft _draft({
  DateTime? startDate,
  DateTime? endDate,
  bool isAllDay = false,
  Duration? startTime = const Duration(hours: 14),
  Duration? endTime = const Duration(hours: 15),
}) {
  return AiEventProposalReviewDraft(
    title: 'Dentist',
    description: 'Check-up',
    startDate: startDate ?? DateTime(2026, 9, 3),
    startTime: startTime,
    endDate: endDate ?? DateTime(2026, 9, 3),
    endTime: endTime,
    isAllDay: isAllDay,
    tags: const ['Personal'],
    reminder: EventReminder.oneHourBefore,
  );
}
