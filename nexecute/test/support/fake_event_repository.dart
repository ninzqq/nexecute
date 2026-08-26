import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/repositories/event_repository.dart';

class FakeEventRepository implements EventRepository {
  FakeEventRepository({this.events = const [], this.state});

  final List<Event> events;
  final DataState<List<Event>>? state;
  final watchedRanges = <CalendarQueryRange>[];
  Event? addedEvent;
  Event? deletedEvent;
  UpdateEventCommand? updateCommand;

  @override
  Stream<DataState<List<Event>>> watchEvents(CalendarQueryRange range) {
    watchedRanges.add(range);
    if (state case final state?) return Stream.value(state);

    final matchingEvents =
        events
            .where(
              (event) =>
                  range.overlaps(start: event.startTime, end: event.endTime),
            )
            .toList();
    return Stream.value(
      matchingEvents.isEmpty
          ? DataEmpty(matchingEvents)
          : DataReady(matchingEvents),
    );
  }

  @override
  Future<Event> addEvent(Event event) async {
    addedEvent = event;
    return event;
  }

  @override
  Future<void> updateEvent(UpdateEventCommand command) async {
    updateCommand = command;
  }

  @override
  Future<void> deleteEvent(Event event) async {
    deletedEvent = event;
  }
}
