import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/repositories/commands/update_event_command.dart';
import 'package:nexecute/repositories/firestore/event_document_mapper.dart';
import 'package:nexecute/services/auth.dart';
import 'package:nexecute/services/authenticated_data_stream.dart';
import 'package:uuid/uuid.dart';

export 'package:nexecute/repositories/commands/update_event_command.dart';

abstract interface class EventRepository {
  Stream<DataState<List<Event>>> watchEvents(CalendarQueryRange range);

  Future<void> addEvent(Event event);

  Future<void> updateEvent(UpdateEventCommand command);

  Future<void> deleteEvent(Event event);
}

class FirestoreEventRepository implements EventRepository {
  FirestoreEventRepository({
    required AuthService authService,
    FirebaseFirestore? firestore,
    Uuid uuid = const Uuid(),
  }) : _authService = authService,
       _db = firestore ?? FirebaseFirestore.instance,
       _uuid = uuid;

  final AuthService _authService;
  final FirebaseFirestore _db;
  final Uuid _uuid;

  @override
  Stream<DataState<List<Event>>> watchEvents(CalendarQueryRange range) {
    return authenticatedDataStream(
      authentication: _authService.userStream,
      isEmpty: (events) => events.isEmpty,
      load:
          (user) => _db
              .collection('users')
              .doc(user.uid)
              .collection('events')
              .where('startTime', isLessThan: range.endExclusive)
              .where('endTime', isGreaterThanOrEqualTo: range.startInclusive)
              .snapshots()
              .map(
                (snapshot) =>
                    snapshot.docs
                        .map(EventDocumentMapper.fromDocument)
                        .toList(),
              ),
    );
  }

  @override
  Future<void> addEvent(Event event) async {
    final ref = _eventsCollection();
    final id = _uuid.v1();
    final data = EventDocumentMapper.toMap(event);
    data['id'] = id;
    await ref.doc(id).set(data);
  }

  @override
  Future<void> updateEvent(UpdateEventCommand command) async {
    if (command.eventId.isEmpty) throw StateError('Event has no ID');

    await _eventsCollection().doc(command.eventId).update({
      'title': command.title,
      'description': command.description,
      'startTime': command.startTime,
      'endTime': command.endTime,
      'isAllDay': command.isAllDay,
      'tags': command.tags,
    });
  }

  @override
  Future<void> deleteEvent(Event event) async {
    if (event.id.isEmpty) throw StateError('Event has no ID');

    try {
      final ref = _eventsCollection().doc(event.id);
      final snapshot = await ref.get();
      if (!snapshot.exists) throw StateError('Event not found');
      await ref.delete();
    } on FirebaseException catch (error) {
      throw Exception('Error deleting event: ${error.message}');
    }
  }

  CollectionReference<Map<String, dynamic>> _eventsCollection() {
    final user = _authService.user;
    if (user == null) throw StateError('User is not logged in');
    return _db.collection('users').doc(user.uid).collection('events');
  }
}
