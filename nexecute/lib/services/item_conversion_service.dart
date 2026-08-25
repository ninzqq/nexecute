import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/repositories/note_repository.dart';

class ItemConversionService {
  const ItemConversionService({
    required EventRepository eventRepository,
    required NoteRepository noteRepository,
  }) : _eventRepository = eventRepository,
       _noteRepository = noteRepository;

  final EventRepository _eventRepository;
  final NoteRepository _noteRepository;

  Future<void> noteToEvent(Quicxec note) async {
    final event = Event(
      id: note.id,
      title: note.title,
      description: note.contentAsPlainText,
      startTime: note.created,
      endTime: note.created,
      tags: note.tags,
    );

    await _eventRepository.addEvent(event);
    await _noteRepository.deletePermanently(note);
  }

  Future<void> eventToNote(Event event) async {
    final note = Quicxec(
      id: event.id,
      title: event.title,
      text: event.description,
      created: event.startTime,
      tags: event.tags,
    );

    await _noteRepository.addNote(note);
    await _eventRepository.deleteEvent(event);
  }
}
