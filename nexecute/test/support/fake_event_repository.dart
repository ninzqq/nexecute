import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/repositories/event_repository.dart';

class FakeEventRepository implements EventRepository {
  FakeEventRepository({this.events = const []});

  final List<Event> events;
  final watchedRanges = <CalendarQueryRange>[];
  Event? addedEvent;
  Event? deletedEvent;

  @override
  Stream<List<Event>> watchEvents(CalendarQueryRange range) {
    watchedRanges.add(range);
    return Stream.value(
      events
          .where(
            (event) =>
                range.overlaps(start: event.startTime, end: event.endTime),
          )
          .toList(),
    );
  }

  @override
  Future<void> addEvent(Event event) async {
    addedEvent = event;
  }

  @override
  Future<void> updateEvent(
    Event event, {
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    required bool isAllDay,
    required List<String> tags,
  }) async {}

  @override
  Future<void> deleteEvent(Event event) async {
    deletedEvent = event;
  }
}
