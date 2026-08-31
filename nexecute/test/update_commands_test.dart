import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/models/event_recurrence.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/repositories/note_repository.dart';

void main() {
  test('event update command captures the complete editable event state', () {
    final tags = ['work'];
    final event = Event(
      id: 'event-1',
      title: 'Planning',
      description: 'Release planning',
      startTime: DateTime(2026, 8, 26, 9),
      endTime: DateTime(2026, 8, 26, 10),
      isAllDay: false,
      tags: tags,
      reminder: EventReminder.fifteenMinutesBefore,
      recurrence: EventRecurrence.monthly,
    );

    final command = UpdateEventCommand.fromEvent(event);
    tags.add('changed-after-command');

    expect(command.eventId, event.id);
    expect(command.title, event.title);
    expect(command.description, event.description);
    expect(command.startTime, event.startTime);
    expect(command.endTime, event.endTime);
    expect(command.isAllDay, event.isAllDay);
    expect(command.tags, ['work']);
    expect(command.reminder, EventReminder.fifteenMinutesBefore);
    expect(command.toEvent().reminder, EventReminder.fifteenMinutesBefore);
    expect(command.recurrence, EventRecurrence.monthly);
    expect(() => command.tags.add('another'), throwsUnsupportedError);
  });

  test('note update command captures the complete editable note state', () {
    final tags = ['personal'];
    final checklistItems = [
      const NoteChecklistItem(id: 'item-1', text: 'Draft release notes'),
    ];
    final note = Quicxec(
      id: 'note-1',
      title: 'Release',
      text: 'Draft release notes',
      created: DateTime(2026, 8, 26),
      tags: tags,
      contentType: NoteContentType.checklist,
      checklistItems: checklistItems,
      folderId: 'projects',
    );

    final command = UpdateNoteCommand.fromNote(note);
    tags.add('changed-after-command');
    checklistItems.add(const NoteChecklistItem(id: 'item-2', text: 'Publish'));

    expect(command.noteId, note.id);
    expect(command.title, note.title);
    expect(command.text, note.text);
    expect(command.tags, ['personal']);
    expect(command.contentType, NoteContentType.checklist);
    expect(command.checklistItems, hasLength(1));
    expect(command.checklistItems.single.id, 'item-1');
    expect(command.folderId, 'projects');
    expect(() => command.checklistItems.clear(), throwsUnsupportedError);
  });
}
