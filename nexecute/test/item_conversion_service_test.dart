import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/repositories/note_repository.dart';
import 'package:nexecute/services/item_conversion_service.dart';

void main() {
  test('converts a note through the injected repositories', () async {
    final events = _FakeEventRepository();
    final notes = _FakeNoteRepository();
    final service = ItemConversionService(
      eventRepository: events,
      noteRepository: notes,
    );
    final note = Quicxec(
      id: 'note-1',
      title: 'Planning',
      text: 'Prepare the release',
      created: DateTime(2026, 8, 25, 9),
      tags: const ['Work'],
    );

    await service.noteToEvent(note);

    expect(events.addedEvent?.title, 'Planning');
    expect(events.addedEvent?.description, 'Prepare the release');
    expect(events.addedEvent?.tags, const ['Work']);
    expect(events.addedEvent?.reminder, EventReminder.fifteenMinutesBefore);
    expect(notes.deletedNote, same(note));
  });

  test('converts an event through the injected repositories', () async {
    final events = _FakeEventRepository();
    final notes = _FakeNoteRepository();
    final service = ItemConversionService(
      eventRepository: events,
      noteRepository: notes,
    );
    final event = Event(
      id: 'event-1',
      title: 'Planning',
      description: 'Prepare the release',
      startTime: DateTime(2026, 8, 25, 9),
      endTime: DateTime(2026, 8, 25, 10),
      tags: const ['Work'],
    );

    await service.eventToNote(event);

    expect(notes.addedNote?.title, 'Planning');
    expect(notes.addedNote?.text, 'Prepare the release');
    expect(notes.addedNote?.tags, const ['Work']);
    expect(events.deletedEvent, same(event));
  });
}

class _FakeEventRepository implements EventRepository {
  Event? addedEvent;
  Event? deletedEvent;

  @override
  Stream<DataState<List<Event>>> watchEvents(CalendarQueryRange range) =>
      Stream.value(const DataEmpty([]));

  @override
  Future<List<Event>> searchEvents(String query, {int limit = 50}) async =>
      const [];

  @override
  Future<Event> addEvent(Event event) async {
    addedEvent = event;
    return event;
  }

  @override
  Future<Event> createEvent(CreateEventCommand command) async =>
      command.toEvent();

  @override
  Future<void> updateEvent(UpdateEventCommand command) async {}

  @override
  Future<void> deleteEvent(Event event) async {
    deletedEvent = event;
  }
}

class _FakeNoteRepository implements NoteRepository {
  Quicxec? addedNote;
  Quicxec? deletedNote;

  @override
  Stream<DataState<List<Quicxec>>> watchNotes() =>
      Stream.value(const DataEmpty([]));

  @override
  Future<void> addNote(Quicxec note) async {
    addedNote = note;
  }

  @override
  Future<void> updateNote(UpdateNoteCommand command) async {}

  @override
  Future<void> moveNote(String noteId, String? folderId) async {}

  @override
  Future<void> setChecklistItemChecked(
    Quicxec note,
    String itemId,
    bool isChecked,
  ) async {}

  @override
  Future<void> toggleTrashed(Quicxec note) async {}

  @override
  Future<void> emptyTrash() async {}

  @override
  Future<void> deletePermanently(Quicxec note) async {
    deletedNote = note;
  }
}
