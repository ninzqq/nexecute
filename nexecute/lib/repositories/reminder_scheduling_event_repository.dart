import 'dart:async';
import 'dart:convert';

import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/services/event_reminder_scheduler.dart';

class ReminderSchedulingEventRepository implements EventRepository {
  ReminderSchedulingEventRepository({
    required EventRepository delegate,
    required EventReminderScheduler reminderScheduler,
  }) : _delegate = delegate,
       _reminderScheduler = reminderScheduler;

  final EventRepository _delegate;
  final EventReminderScheduler _reminderScheduler;
  final Map<String, String> _desiredFingerprints = {};
  final Map<String, String> _appliedFingerprints = {};
  final Map<String, Future<void>> _operationTails = {};
  Future<void> _reconciliationTail = Future<void>.value();
  bool _comparedPendingEvents = false;
  StreamSubscription<DataState<List<Event>>>? _reconciliationSubscription;

  @override
  Stream<DataState<List<Event>>> watchEvents(CalendarQueryRange range) {
    _startReconciliation();
    return _delegate.watchEvents(range);
  }

  @override
  Future<List<Event>> searchEvents(String query, {int limit = 50}) {
    return _delegate.searchEvents(query, limit: limit);
  }

  @override
  Future<Event> addEvent(Event event) async {
    final savedEvent = await _delegate.addEvent(event);
    await _scheduleAndWait(savedEvent);
    return savedEvent;
  }

  @override
  Future<Event> createEvent(CreateEventCommand command) async {
    final savedEvent = await _delegate.createEvent(command);
    await _scheduleAndWait(savedEvent);
    return savedEvent;
  }

  @override
  Future<void> updateEvent(UpdateEventCommand command) async {
    await _delegate.updateEvent(command);
    await _scheduleAndWait(command.toEvent());
  }

  @override
  Future<void> deleteEvent(Event event) async {
    await _delegate.deleteEvent(event);
    _desiredFingerprints.remove(event.id);
    _appliedFingerprints.remove(event.id);
    await _enqueue(event.id, () => _cancelSafely(event.id));
  }

  void _startReconciliation() {
    if (_reconciliationSubscription != null ||
        _delegate is! EventReminderSource) {
      return;
    }
    final source = _delegate as EventReminderSource;
    _reconciliationSubscription = source.watchReminderEvents().listen(
      _queueReconciliation,
      onError: (_) {},
    );
  }

  void _queueReconciliation(DataState<List<Event>> state) {
    _reconciliationTail = _reconciliationTail
        .then((_) => _reconcile(state))
        .catchError((_) {});
  }

  Future<void> _reconcile(DataState<List<Event>> state) async {
    if (state is DataUnauthenticated<List<Event>>) {
      final eventIds =
          _desiredFingerprints.keys.toSet()
            ..addAll(await _readPendingEventIds());
      for (final eventId in eventIds) {
        await _cancelAndWait(eventId);
      }
      _comparedPendingEvents = false;
      return;
    }

    final events = state.valueOrNull;
    if (events == null) return;
    final eventsById = <String, Event>{
      for (final event in events) event.id: event,
    };
    if (!_comparedPendingEvents) {
      final pendingEventIds = await _readPendingEventIds();
      for (final staleId in pendingEventIds.difference(
        eventsById.keys.toSet(),
      )) {
        await _cancelAndWait(staleId);
      }
      _comparedPendingEvents = true;
    }
    for (final removedId in _desiredFingerprints.keys.toSet().difference(
      eventsById.keys.toSet(),
    )) {
      await _cancelAndWait(removedId);
    }
    for (final event in eventsById.values) {
      await _scheduleAndWait(event);
    }
  }

  Future<void> _scheduleAndWait(Event event) {
    final fingerprint = _eventFingerprint(event);
    _desiredFingerprints[event.id] = fingerprint;
    return _enqueue(event.id, () async {
      if (_desiredFingerprints[event.id] != fingerprint ||
          _appliedFingerprints[event.id] == fingerprint) {
        return;
      }
      final status = await _scheduleSafely(event);
      if (_desiredFingerprints[event.id] == fingerprint && _isSettled(status)) {
        _appliedFingerprints[event.id] = fingerprint;
      }
    });
  }

  Future<void> _cancelAndWait(String eventId) {
    _desiredFingerprints.remove(eventId);
    _appliedFingerprints.remove(eventId);
    return _enqueue(eventId, () => _cancelSafely(eventId));
  }

  Future<Set<String>> _readPendingEventIds() async {
    final scheduler = _reminderScheduler;
    if (scheduler is! PendingEventReminderReader) return const {};
    try {
      return await (scheduler as PendingEventReminderReader).pendingEventIds();
    } catch (_) {
      return const {};
    }
  }

  Future<EventReminderScheduleStatus> _scheduleSafely(Event event) async {
    try {
      return await _reminderScheduler.schedule(event);
    } catch (_) {
      // The Firestore write succeeded; local notification availability is a
      // separate concern and must not make the persisted operation fail.
      return EventReminderScheduleStatus.failed;
    }
  }

  Future<void> _cancelSafely(String eventId) async {
    try {
      await _reminderScheduler.cancel(eventId);
    } catch (_) {
      // A local cancellation failure must not make a synchronized Firestore
      // mutation appear to have failed.
    }
  }

  Future<void> _enqueue(String eventId, Future<void> Function() operation) {
    final previous = _operationTails[eventId] ?? Future<void>.value();
    final next = previous.then((_) => operation());
    _operationTails[eventId] = next;
    return next.whenComplete(() {
      if (identical(_operationTails[eventId], next)) {
        _operationTails.remove(eventId);
      }
    });
  }
}

bool _isSettled(EventReminderScheduleStatus status) => switch (status) {
  EventReminderScheduleStatus.scheduled ||
  EventReminderScheduleStatus.notRequested ||
  EventReminderScheduleStatus.triggerInPast ||
  EventReminderScheduleStatus.permissionDenied ||
  EventReminderScheduleStatus.unsupported => true,
  EventReminderScheduleStatus.failed => false,
};

String _eventFingerprint(Event event) => jsonEncode([
  event.id,
  event.title,
  event.description,
  event.seriesStartTime.toIso8601String(),
  event.seriesEndTime.toIso8601String(),
  event.isAllDay,
  event.tags,
  event.reminder.name,
  event.recurrence.name,
]);
