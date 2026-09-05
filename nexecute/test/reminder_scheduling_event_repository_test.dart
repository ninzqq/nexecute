import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/models/event_recurrence.dart';
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

  test(
    'schedules a deterministically created event through the same pipeline',
    () async {
      final delegate = _RecordingEventRepository();
      final scheduler = _RecordingReminderScheduler();
      final repository = ReminderSchedulingEventRepository(
        delegate: delegate,
        reminderScheduler: scheduler,
      );
      final command = CreateEventCommand(
        creationId: 'creation-1',
        sourceNoteId: 'note-1',
        title: 'Planning',
        description: '',
        startTime: DateTime(2026, 9, 1, 10),
        endTime: DateTime(2026, 9, 1, 11),
        isAllDay: false,
        tags: const ['Work'],
        reminder: EventReminder.fifteenMinutesBefore,
        createdAt: DateTime.utc(2026, 8, 30),
      );

      final saved = await repository.createEvent(command);

      expect(delegate.createCommand, same(command));
      expect(saved.id, command.eventId);
      expect(scheduler.scheduledEvents.single.id, command.eventId);
      expect(
        scheduler.scheduledEvents.single.reminder,
        EventReminder.fifteenMinutesBefore,
      );
    },
  );

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
    'reconciles synchronized events into local reminders on this device',
    () async {
      final delegate = _RecordingEventRepository();
      final scheduler = _RecordingReminderScheduler();
      final repository = ReminderSchedulingEventRepository(
        delegate: delegate,
        reminderScheduler: scheduler,
      );
      final visibleSubscription = repository
          .watchEvents(_range())
          .listen((_) {});
      addTearDown(visibleSubscription.cancel);
      addTearDown(delegate.dispose);

      delegate.reminderStates.add(DataReady([_event(id: 'synced-event')]));
      await _flushAsyncWork();

      expect(scheduler.scheduledEvents, hasLength(1));
      expect(scheduler.scheduledEvents.single.id, 'synced-event');
    },
  );

  test('deduplicates unchanged reminder snapshots and applies edits', () async {
    final delegate = _RecordingEventRepository();
    final scheduler = _RecordingReminderScheduler();
    final repository = ReminderSchedulingEventRepository(
      delegate: delegate,
      reminderScheduler: scheduler,
    );
    final visibleSubscription = repository.watchEvents(_range()).listen((_) {});
    addTearDown(visibleSubscription.cancel);
    addTearDown(delegate.dispose);
    final event = _event(id: 'synced-event');

    delegate.reminderStates.add(DataReady([event]));
    delegate.reminderStates.add(DataReady([event]));
    await _flushAsyncWork();
    delegate.reminderStates.add(
      DataReady([event.copyWith(reminder: EventReminder.oneHourBefore)]),
    );
    await _flushAsyncWork();

    expect(scheduler.scheduledEvents, hasLength(2));
    expect(
      scheduler.scheduledEvents.last.reminder,
      EventReminder.oneHourBefore,
    );
  });

  test(
    'does not repeatedly request denied access on unchanged snapshots',
    () async {
      final delegate = _RecordingEventRepository();
      final scheduler =
          _RecordingReminderScheduler()
            ..scheduleStatus = EventReminderScheduleStatus.permissionDenied;
      final repository = ReminderSchedulingEventRepository(
        delegate: delegate,
        reminderScheduler: scheduler,
      );
      final visibleSubscription = repository
          .watchEvents(_range())
          .listen((_) {});
      addTearDown(visibleSubscription.cancel);
      addTearDown(delegate.dispose);
      final event = _event(id: 'permission-denied');

      delegate.reminderStates.add(DataReady([event]));
      delegate.reminderStates.add(DataReady([event]));
      await _flushAsyncWork();

      expect(scheduler.scheduledEvents, hasLength(1));
    },
  );

  test('cancels local reminders removed by synchronization', () async {
    final delegate = _RecordingEventRepository();
    final scheduler = _RecordingReminderScheduler();
    final repository = ReminderSchedulingEventRepository(
      delegate: delegate,
      reminderScheduler: scheduler,
    );
    final visibleSubscription = repository.watchEvents(_range()).listen((_) {});
    addTearDown(visibleSubscription.cancel);
    addTearDown(delegate.dispose);

    delegate.reminderStates.add(DataReady([_event(id: 'remote-delete')]));
    await _flushAsyncWork();
    delegate.reminderStates.add(const DataEmpty([]));
    await _flushAsyncWork();

    expect(scheduler.cancelledIds, ['remote-delete']);
  });

  test('cancels reminders deleted while this device was offline', () async {
    final delegate = _RecordingEventRepository();
    final scheduler =
        _RecordingReminderScheduler()..pendingIds.add('offline-delete');
    final repository = ReminderSchedulingEventRepository(
      delegate: delegate,
      reminderScheduler: scheduler,
    );
    final visibleSubscription = repository.watchEvents(_range()).listen((_) {});
    addTearDown(visibleSubscription.cancel);
    addTearDown(delegate.dispose);

    delegate.reminderStates.add(const DataEmpty([]));
    await _flushAsyncWork();

    expect(scheduler.cancelledIds, ['offline-delete']);
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

  test('maps event recurrence to repeating notification components', () {
    expect(eventReminderDateTimeComponents(EventRecurrence.none), isNull);
    expect(
      eventReminderDateTimeComponents(EventRecurrence.daily),
      DateTimeComponents.time,
    );
    expect(
      eventReminderDateTimeComponents(EventRecurrence.weekly),
      DateTimeComponents.dayOfWeekAndTime,
    );
    expect(
      eventReminderDateTimeComponents(EventRecurrence.monthly),
      DateTimeComponents.dayOfMonthAndTime,
    );
    expect(
      eventReminderDateTimeComponents(EventRecurrence.yearly),
      DateTimeComponents.dateAndTime,
    );
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

CalendarQueryRange _range() => CalendarQueryRange(
  startInclusive: DateTime(2026, 8, 1),
  endExclusive: DateTime(2026, 10, 1),
);

Future<void> _flushAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _RecordingEventRepository
    implements EventRepository, EventReminderSource {
  Event? addedEvent;
  Event? deletedEvent;
  UpdateEventCommand? updateCommand;
  CreateEventCommand? createCommand;
  String? searchQuery;
  int? searchLimit;
  final reminderStates = StreamController<DataState<List<Event>>>.broadcast(
    sync: true,
  );

  @override
  Stream<DataState<List<Event>>> watchEvents(CalendarQueryRange range) {
    return Stream.value(const DataEmpty([]));
  }

  @override
  Stream<DataState<List<Event>>> watchReminderEvents() {
    return reminderStates.stream;
  }

  Future<void> dispose() => reminderStates.close();

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
  Future<Event> createEvent(CreateEventCommand command) async {
    createCommand = command;
    return command.toEvent();
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

class _RecordingReminderScheduler
    implements EventReminderScheduler, PendingEventReminderReader {
  @override
  Future<EventReminderPermissionStatus> checkPermissionStatus() async {
    return EventReminderPermissionStatus.authorized;
  }

  @override
  Future<EventReminderPermissionStatus> requestPermission() async {
    return EventReminderPermissionStatus.authorized;
  }

  final scheduledEvents = <Event>[];
  final cancelledIds = <String>[];
  final pendingIds = <String>{};
  EventReminderScheduleStatus scheduleStatus =
      EventReminderScheduleStatus.scheduled;

  @override
  Future<EventReminderScheduleStatus> schedule(Event event) async {
    scheduledEvents.add(event);
    return scheduleStatus;
  }

  @override
  Future<void> cancel(String eventId) async {
    cancelledIds.add(eventId);
    pendingIds.remove(eventId);
  }

  @override
  Future<Set<String>> pendingEventIds() async => pendingIds.toSet();
}

class _ThrowingReminderScheduler implements EventReminderScheduler {
  @override
  Future<EventReminderPermissionStatus> checkPermissionStatus() async {
    throw StateError('Reminder permissions unavailable');
  }

  @override
  Future<EventReminderPermissionStatus> requestPermission() async {
    throw StateError('Reminder permissions unavailable');
  }

  @override
  Future<EventReminderScheduleStatus> schedule(Event event) {
    throw StateError('Notifications unavailable');
  }

  @override
  Future<void> cancel(String eventId) {
    throw StateError('Notifications unavailable');
  }
}
