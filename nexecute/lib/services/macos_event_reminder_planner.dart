import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/domain/calendar/recurring_event_expander.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/services/event_reminder_scheduler.dart';
import 'package:timezone/timezone.dart' as tz;

const macOSEventReminderHorizonMonths = 24;
const macOSEventReminderCapacity = 48;

final class MacOSEventReminderRequest {
  const MacOSEventReminderRequest({
    required this.notificationId,
    required this.event,
    required this.kind,
    required this.occurrenceKey,
    required this.occurrenceStart,
    required this.scheduledDate,
  });

  final int notificationId;
  final Event event;
  final EventReminderNotificationKind kind;
  final String occurrenceKey;
  final tz.TZDateTime occurrenceStart;
  final tz.TZDateTime scheduledDate;

  String get notificationTitle => eventReminderNotificationTitle(event, kind);

  String get notificationBody => eventReminderNotificationBody(event, kind);
}

final class MacOSEventReminderPlan {
  const MacOSEventReminderPlan({
    required this.requests,
    required this.waitingForCapacity,
  });

  final List<MacOSEventReminderRequest> requests;
  final int waitingForCapacity;

  bool get isCapacityLimited => waitingForCapacity > 0;
}

/// Builds the complete desired set of macOS event-notification requests.
///
/// This class deliberately has no plugin or persistence dependency. The
/// lifecycle reconciler can compare its deterministic output with pending
/// operating-system requests and apply only the required changes.
final class MacOSEventReminderPlanner {
  const MacOSEventReminderPlanner({
    this.horizonMonths = macOSEventReminderHorizonMonths,
    this.capacity = macOSEventReminderCapacity,
  }) : assert(horizonMonths > 0),
       assert(capacity > 0);

  final int horizonMonths;
  final int capacity;

  MacOSEventReminderPlan build({
    required String accountId,
    required Iterable<Event> events,
    required tz.Location location,
    required tz.TZDateTime now,
  }) {
    final candidates = <MacOSEventReminderRequest>[];
    for (final event in events) {
      if (event.reminder.minutesBefore == null) continue;
      if (event.recurrence.repeats) {
        candidates.addAll(
          _recurringRequests(
            accountId: accountId,
            event: event,
            location: location,
            now: now,
          ),
        );
      } else {
        candidates.addAll(
          _oneShotRequests(
            accountId: accountId,
            event: event,
            location: location,
            now: now,
          ),
        );
      }
    }

    candidates.sort((first, second) {
      final byDate = first.scheduledDate.compareTo(second.scheduledDate);
      if (byDate != 0) return byDate;
      return first.notificationId.compareTo(second.notificationId);
    });
    final selected = candidates.take(capacity).toList(growable: false);
    return MacOSEventReminderPlan(
      requests: selected,
      waitingForCapacity: candidates.length - selected.length,
    );
  }

  Iterable<MacOSEventReminderRequest> _oneShotRequests({
    required String accountId,
    required Event event,
    required tz.Location location,
    required tz.TZDateTime now,
  }) sync* {
    final occurrenceStart = _inLocation(event.seriesStartTime, location);
    const occurrenceKey = 'single';
    for (final timing in _reminderTimings(event, occurrenceStart, location)) {
      if (!timing.scheduledDate.isAfter(now)) continue;
      yield _request(
        accountId: accountId,
        event: event,
        kind: timing.kind,
        occurrenceKey: occurrenceKey,
        occurrenceStart: occurrenceStart,
        scheduledDate: timing.scheduledDate,
      );
    }
  }

  Iterable<MacOSEventReminderRequest> _recurringRequests({
    required String accountId,
    required Event event,
    required tz.Location location,
    required tz.TZDateTime now,
  }) sync* {
    final rangeStart = DateTime(now.year, now.month, now.day);
    final rangeEnd = DateTime(
      now.year,
      now.month + horizonMonths,
      now.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
    final occurrences = expandRecurringEvent(
      event,
      CalendarQueryRange(startInclusive: rangeStart, endExclusive: rangeEnd),
    );
    for (final occurrence in occurrences) {
      final occurrenceStart = _inLocation(occurrence.startTime, location);
      final occurrenceKey = _occurrenceKey(occurrenceStart);
      for (final timing in _reminderTimings(event, occurrenceStart, location)) {
        if (!timing.scheduledDate.isAfter(now)) continue;
        yield _request(
          accountId: accountId,
          event: event,
          kind: timing.kind,
          occurrenceKey: occurrenceKey,
          occurrenceStart: occurrenceStart,
          scheduledDate: timing.scheduledDate,
        );
      }
    }
  }

  MacOSEventReminderRequest _request({
    required String accountId,
    required Event event,
    required EventReminderNotificationKind kind,
    required String occurrenceKey,
    required tz.TZDateTime occurrenceStart,
    required tz.TZDateTime scheduledDate,
  }) {
    return MacOSEventReminderRequest(
      notificationId: macOSEventReminderNotificationId(
        accountId: accountId,
        eventId: event.id,
        occurrenceKey: occurrenceKey,
        kind: kind,
      ),
      event: event,
      kind: kind,
      occurrenceKey: occurrenceKey,
      occurrenceStart: occurrenceStart,
      scheduledDate: scheduledDate,
    );
  }
}

int macOSEventReminderNotificationId({
  required String accountId,
  required String eventId,
  required String occurrenceKey,
  EventReminderNotificationKind kind = EventReminderNotificationKind.standard,
}) => eventReminderNotificationId(
  'nexecute:macos:event-reminder:$accountId:$eventId:$occurrenceKey',
  kind,
);

Iterable<_ReminderTiming> _reminderTimings(
  Event event,
  tz.TZDateTime occurrenceStart,
  tz.Location location,
) sync* {
  if (event.isAllDay) {
    yield _ReminderTiming(
      kind: EventReminderNotificationKind.allDayTomorrow,
      scheduledDate: tz.TZDateTime(
        location,
        occurrenceStart.year,
        occurrenceStart.month,
        occurrenceStart.day - 1,
        21,
      ),
    );
    yield _ReminderTiming(
      kind: EventReminderNotificationKind.allDayToday,
      scheduledDate: tz.TZDateTime(
        location,
        occurrenceStart.year,
        occurrenceStart.month,
        occurrenceStart.day,
        9,
      ),
    );
    return;
  }

  final minutesBefore = event.reminder.minutesBefore!;
  yield _ReminderTiming(
    kind: EventReminderNotificationKind.standard,
    scheduledDate: tz.TZDateTime.from(
      occurrenceStart.subtract(Duration(minutes: minutesBefore)),
      location,
    ),
  );
}

final class _ReminderTiming {
  const _ReminderTiming({required this.kind, required this.scheduledDate});

  final EventReminderNotificationKind kind;
  final tz.TZDateTime scheduledDate;
}

tz.TZDateTime _inLocation(DateTime value, tz.Location location) {
  final resolved = tz.TZDateTime(
    location,
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
  final priorOffset =
      tz.TZDateTime.from(
        resolved.subtract(const Duration(days: 1)),
        location,
      ).timeZoneOffset;
  final overlap = priorOffset - resolved.timeZoneOffset;
  if (overlap > Duration.zero) {
    final earlier = tz.TZDateTime.from(resolved.subtract(overlap), location);
    if (_hasSameWallTime(earlier, value)) return earlier;
  }
  return resolved;
}

bool _hasSameWallTime(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day &&
    first.hour == second.hour &&
    first.minute == second.minute &&
    first.second == second.second &&
    first.millisecond == second.millisecond &&
    first.microsecond == second.microsecond;

String _occurrenceKey(tz.TZDateTime value) {
  String twoDigits(int part) => part.toString().padLeft(2, '0');
  return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}T'
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}:'
      '${twoDigits(value.second)}.${value.millisecond.toString().padLeft(3, '0')}'
      '${value.microsecond.toString().padLeft(3, '0')}';
}
