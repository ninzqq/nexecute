import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/domain/calendar/recurring_event_expander.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/repositories/commands/create_event_command.dart';
import 'package:nexecute/repositories/commands/update_event_command.dart';
import 'package:nexecute/repositories/firestore/event_document_mapper.dart';
import 'package:nexecute/repositories/firestore/schema/app_data_schema.dart';
import 'package:nexecute/search/search_matcher.dart';
import 'package:nexecute/services/auth.dart';
import 'package:nexecute/services/authenticated_data_stream.dart';
import 'package:uuid/uuid.dart';
import 'package:rxdart/rxdart.dart';

export 'package:nexecute/repositories/commands/update_event_command.dart';
export 'package:nexecute/repositories/commands/create_event_command.dart';

abstract interface class EventRepository {
  Stream<DataState<List<Event>>> watchEvents(CalendarQueryRange range);

  Future<List<Event>> searchEvents(String query, {int limit = 50});

  Future<Event> addEvent(Event event);

  Future<Event> createEvent(CreateEventCommand command);

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
      load: (user) {
        final events = _db
            .collection('users')
            .doc(user.uid)
            .collection('events');
        final overlapping =
            events
                .where('startTime', isLessThan: range.endExclusive)
                .where('endTime', isGreaterThanOrEqualTo: range.startInclusive)
                .snapshots();
        final recurring =
            events.where('isRecurring', isEqualTo: true).snapshots();

        return Rx.combineLatest2(overlapping, recurring, (
          QuerySnapshot<Map<String, dynamic>> overlappingSnapshot,
          QuerySnapshot<Map<String, dynamic>> recurringSnapshot,
        ) {
          final oneOffEvents = overlappingSnapshot.docs
              .map(EventDocumentMapper.fromDocument)
              .where((event) => !event.recurrence.repeats);
          final recurringEvents = recurringSnapshot.docs
              .map(EventDocumentMapper.fromDocument)
              .where((event) => event.recurrence.repeats);
          final visibleEvents = <Event>[
            ...oneOffEvents,
            ...expandRecurringEvents(recurringEvents, range),
          ]..sort(
            (first, second) => first.startTime.compareTo(second.startTime),
          );
          return visibleEvents;
        });
      },
    );
  }

  @override
  Future<List<Event>> searchEvents(String query, {int limit = 50}) async {
    final normalizedQuery = normalizeSearchQuery(query);
    if (normalizedQuery.isEmpty || limit <= 0) return const [];

    final snapshot = await _eventsCollection().get();
    final matches =
        snapshot.docs
            .map(EventDocumentMapper.fromDocument)
            .where((event) => eventMatchesSearch(event, normalizedQuery))
            .toList()
          ..sort(
            (first, second) => second.startTime.compareTo(first.startTime),
          );
    return matches.take(limit).toList(growable: false);
  }

  @override
  Future<Event> addEvent(Event event) async {
    final ref = _eventsCollection();
    final id = _uuid.v1();
    final savedEvent = event.copyWith(id: id);
    final data = EventDocumentMapper.toMap(savedEvent);
    await ref.doc(id).set(data);
    return savedEvent;
  }

  @override
  Future<Event> createEvent(CreateEventCommand command) async {
    final event = command.toEvent();
    await _eventsCollection()
        .doc(event.id)
        .set(EventDocumentMapper.toCreateMap(command));
    return event;
  }

  @override
  Future<void> updateEvent(UpdateEventCommand command) async {
    if (command.eventId.isEmpty) throw StateError('Event has no ID');

    await _eventsCollection()
        .doc(command.eventId)
        .update(
          AppDataSchema.stamp({
            'title': command.title,
            'description': command.description,
            'startTime': command.startTime,
            'endTime': command.endTime,
            'isAllDay': command.isAllDay,
            'tags': command.tags,
            'reminderMinutesBefore': command.reminder.minutesBefore,
            'recurrence': command.recurrence.name,
            'isRecurring': command.recurrence.repeats,
          }),
        );
  }

  @override
  Future<void> deleteEvent(Event event) async {
    if (event.id.isEmpty) throw StateError('Event has no ID');

    try {
      await _eventsCollection().doc(event.id).delete();
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
