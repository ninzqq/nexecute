import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:test/test.dart';

void main() {
  test('normalizes reviewed values and creates a deterministic event ID', () {
    final tags = [' Work ', 'Personal'];
    final createdAt = DateTime.utc(2026, 8, 30, 12);
    final command = CreateEventCommand(
      creationId: 'creation-1',
      sourceNoteId: 'note-1',
      title: ' Planning session ',
      description: ' Prepare release notes. ',
      startTime: DateTime(2026, 9, 3, 14),
      endTime: DateTime(2026, 9, 3, 15),
      isAllDay: false,
      tags: tags,
      reminder: EventReminder.fifteenMinutesBefore,
      createdAt: createdAt,
    );
    tags.add('Later mutation');

    expect(command.eventId, 'ai-event-creation-1');
    expect(command.title, 'Planning session');
    expect(command.description, 'Prepare release notes.');
    expect(command.tags, ['Work', 'Personal']);
    expect(command.createdAt, createdAt);
    expect(command.toEvent().id, command.eventId);
    expect(command.toEvent().reminder, EventReminder.fifteenMinutesBefore);
  });

  test('accepts inclusive all-day dates at local midnight', () {
    final command = _command(
      startTime: DateTime(2026, 9, 3),
      endTime: DateTime(2026, 9, 5),
      isAllDay: true,
    );

    expect(command.toEvent().startTime, DateTime(2026, 9, 3));
    expect(command.toEvent().endTime, DateTime(2026, 9, 5));
    expect(command.toEvent().isAllDay, isTrue);
  });

  test('rejects unsafe identifiers and invalid or excessive ranges', () {
    expect(() => _command(creationId: 'unsafe/value'), throwsArgumentError);
    expect(() => _command(sourceNoteId: 'notes/source'), throwsArgumentError);
    expect(
      () => _command(
        startTime: DateTime(2026, 9, 3, 15),
        endTime: DateTime(2026, 9, 3, 14),
      ),
      throwsArgumentError,
    );
    expect(
      () => _command(
        startTime: DateTime(2026, 9, 3, 9),
        endTime: DateTime(2027, 9, 4, 9),
      ),
      throwsArgumentError,
    );
    expect(
      () => _command(
        startTime: DateTime(2026, 9, 3, 9),
        endTime: DateTime(2026, 9, 3, 10),
        isAllDay: true,
      ),
      throwsArgumentError,
    );
    expect(
      () => _command(
        startTime: DateTime.utc(2026, 9, 3, 9),
        endTime: DateTime.utc(2026, 9, 3, 10),
      ),
      throwsArgumentError,
    );
  });
}

CreateEventCommand _command({
  String creationId = 'creation-1',
  String sourceNoteId = 'note-1',
  DateTime? startTime,
  DateTime? endTime,
  bool isAllDay = false,
}) {
  return CreateEventCommand(
    creationId: creationId,
    sourceNoteId: sourceNoteId,
    title: 'Planning',
    description: '',
    startTime: startTime ?? DateTime(2026, 9, 3, 14),
    endTime: endTime ?? DateTime(2026, 9, 3, 15),
    isAllDay: isAllDay,
    tags: const [],
    reminder: EventReminder.none,
    createdAt: DateTime.utc(2026, 8, 30),
  );
}
