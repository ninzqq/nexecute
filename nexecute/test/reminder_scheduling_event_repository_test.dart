import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/repositories/reminder_scheduling_event_repository.dart';
import 'package:nexecute/services/event_reminder_scheduler.dart';
import 'package:test/test.dart';

void main() {
  test('schedules reminders after event creates and updates', () async {
    final delegate = _RecordingEventRepository();
    final scheduler = _RecordingReminderScheduler();
    final repository = ReminderSchedulingEventRepository(
      delegate: delegate,
      reminderScheduler: scheduler,
    );
    final event = _event(id: '');

    final saved = await repository.addEvent(event);
    final update = UpdateEventCommand.fromEvent(
      saved.copyWith(reminder: EventReminder.oneHourBefore),
    );
    await repository.updateEvent(update);

    expect(saved.id, 'stored-event');
    expect(scheduler.scheduledEvents, hasLength(2));
    expect(scheduler.scheduledEvents.first.id, 'stored-event');
    expect(
      scheduler.scheduledEvents.last.reminder,
      EventReminder.oneHourBefore,
    );
  });

  test('cancels the local reminder after deleting an event', () async {
    final delegate = _RecordingEventRepository();
    final scheduler = _RecordingReminderScheduler();
    final repository = ReminderSchedulingEventRepository(
      delegate: delegate,
      reminderScheduler: scheduler,
    );
    final event = _event(id: 'event-to-delete');

    await repository.deleteEvent(event);

    expect(delegate.deletedEvent, same(event));
    expect(scheduler.cancelledIds, ['event-to-delete']);
  });

  test('a local scheduler failure does not mask a successful write', () async {
    final delegate = _RecordingEventRepository();
    final repository = ReminderSchedulingEventRepository(
      delegate: delegate,
      reminderScheduler: _ThrowingReminderScheduler(),
    );

    final saved = await repository.addEvent(_event(id: ''));

    expect(saved.id, 'stored-event');
    expect(delegate.addedEvent, isNotNull);
  });

  test(
    'forwards event searches without involving the reminder scheduler',
    () async {
      final delegate = _RecordingEventRepository();
      final scheduler = _RecordingReminderScheduler();
      final repository = ReminderSchedulingEventRepository(
        delegate: delegate,
        reminderScheduler: scheduler,
      );

      await repository.searchEvents('planning', limit: 12);

      expect(delegate.searchQuery, 'planning');
      expect(delegate.searchLimit, 12);
      expect(scheduler.scheduledEvents, isEmpty);
    },
  );

  test('notification IDs are stable and non-negative', () {
    final first = eventReminderNotificationId('event-1');

    expect(eventReminderNotificationId('event-1'), first);
    expect(eventReminderNotificationId('event-2'), isNot(first));
    expect(first, greaterThanOrEqualTo(0));
  });
}

Event _event({required String id}) {
  return Event(
    id: id,
    title: 'Planning',
    startTime: DateTime(2026, 9, 1, 10),
    endTime: DateTime(2026, 9, 1, 11),
    reminder: EventReminder.fifteenMinutesBefore,
  );
}

class _RecordingEventRepository implements EventRepository {
  Event? addedEvent;
  Event? deletedEvent;
  UpdateEventCommand? updateCommand;
  String? searchQuery;
  int? searchLimit;

  @override
  Stream<DataState<List<Event>>> watchEvents(CalendarQueryRange range) {
    return Stream.value(const DataEmpty([]));
  }

  @override
  Future<List<Event>> searchEvents(String query, {int limit = 50}) async {
    searchQuery = query;
    searchLimit = limit;
    return const [];
  }

  @override
  Future<Event> addEvent(Event event) async {
    addedEvent = event;
    return event.copyWith(id: 'stored-event');
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

class _RecordingReminderScheduler implements EventReminderScheduler {
  final scheduledEvents = <Event>[];
  final cancelledIds = <String>[];

  @override
  Future<EventReminderScheduleStatus> schedule(Event event) async {
    scheduledEvents.add(event);
    return EventReminderScheduleStatus.scheduled;
  }

  @override
  Future<void> cancel(String eventId) async {
    cancelledIds.add(eventId);
  }
}

class _ThrowingReminderScheduler implements EventReminderScheduler {
  @override
  Future<EventReminderScheduleStatus> schedule(Event event) {
    throw StateError('Notifications unavailable');
  }

  @override
  Future<void> cancel(String eventId) {
    throw StateError('Notifications unavailable');
  }
}
