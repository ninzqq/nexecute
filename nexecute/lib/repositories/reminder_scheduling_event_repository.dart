import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/services/event_reminder_scheduler.dart';

class ReminderSchedulingEventRepository implements EventRepository {
  const ReminderSchedulingEventRepository({
    required EventRepository delegate,
    required EventReminderScheduler reminderScheduler,
  }) : _delegate = delegate,
       _reminderScheduler = reminderScheduler;

  final EventRepository _delegate;
  final EventReminderScheduler _reminderScheduler;

  @override
  Stream<DataState<List<Event>>> watchEvents(CalendarQueryRange range) {
    return _delegate.watchEvents(range);
  }

  @override
  Future<List<Event>> searchEvents(String query, {int limit = 50}) {
    return _delegate.searchEvents(query, limit: limit);
  }

  @override
  Future<Event> addEvent(Event event) async {
    final savedEvent = await _delegate.addEvent(event);
    await _scheduleSafely(savedEvent);
    return savedEvent;
  }

  @override
  Future<Event> createEvent(CreateEventCommand command) async {
    final savedEvent = await _delegate.createEvent(command);
    await _scheduleSafely(savedEvent);
    return savedEvent;
  }

  @override
  Future<void> updateEvent(UpdateEventCommand command) async {
    await _delegate.updateEvent(command);
    await _scheduleSafely(command.toEvent());
  }

  @override
  Future<void> deleteEvent(Event event) async {
    await _delegate.deleteEvent(event);
    try {
      await _reminderScheduler.cancel(event.id);
    } catch (_) {
      // The Firestore deletion succeeded; a local cancellation failure must
      // not make the persisted operation appear to have failed.
    }
  }

  Future<void> _scheduleSafely(Event event) async {
    try {
      await _reminderScheduler.schedule(event);
    } catch (_) {
      // The Firestore write succeeded; local notification availability is a
      // separate concern and must not make the persisted operation fail.
    }
  }
}
