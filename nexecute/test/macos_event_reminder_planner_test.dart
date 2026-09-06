import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_recurrence.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/services/macos_event_reminder_planner.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location helsinki;
  late MacOSEventReminderPlanner planner;

  setUpAll(tz_data.initializeTimeZones);

  setUp(() {
    helsinki = tz.getLocation('Europe/Helsinki');
    planner = const MacOSEventReminderPlanner();
  });

  test('keeps the nearest 48 requests across all event series', () {
    final plan = planner.build(
      accountId: 'account-a',
      events: [
        _event(
          id: 'daily',
          start: DateTime(2026, 9, 1, 9),
          recurrence: EventRecurrence.daily,
        ),
        _event(
          id: 'nearer',
          start: DateTime(2026, 9, 6, 8),
          recurrence: EventRecurrence.none,
        ),
      ],
      location: helsinki,
      now: tz.TZDateTime(helsinki, 2026, 9, 6, 7),
    );

    expect(plan.requests, hasLength(48));
    expect(plan.isCapacityLimited, isTrue);
    expect(plan.waitingForCapacity, greaterThan(600));
    expect(plan.requests.first.event.id, 'nearer');
    final scheduledDates =
        plan.requests.map((request) => request.scheduledDate).toList();
    expect(scheduledDates, orderedEquals([...scheduledDates]..sort()));
  });

  test('uses month-end clamping from the shared recurrence rules', () {
    final plan = planner.build(
      accountId: 'account-a',
      events: [
        _event(
          id: 'month-end',
          start: DateTime(2026, 1, 31, 9),
          recurrence: EventRecurrence.monthly,
          reminder: EventReminder.atStart,
        ),
      ],
      location: helsinki,
      now: tz.TZDateTime(helsinki, 2026, 2, 1),
    );

    expect(plan.requests.take(3).map((request) => request.occurrenceStart), [
      tz.TZDateTime(helsinki, 2026, 2, 28, 9),
      tz.TZDateTime(helsinki, 2026, 3, 31, 9),
      tz.TZDateTime(helsinki, 2026, 4, 30, 9),
    ]);
  });

  test('maps leap-day anniversaries to February 28', () {
    final plan = planner.build(
      accountId: 'account-a',
      events: [
        _event(
          id: 'leap-day',
          start: DateTime(2024, 2, 29, 10),
          recurrence: EventRecurrence.yearly,
          reminder: EventReminder.atStart,
        ),
      ],
      location: helsinki,
      now: tz.TZDateTime(helsinki, 2025, 1, 1),
    );

    expect(
      plan.requests.first.occurrenceStart,
      tz.TZDateTime(helsinki, 2025, 2, 28, 10),
    );
  });

  test('keeps reminder offsets that cross a calendar-day boundary', () {
    final plan = planner.build(
      accountId: 'account-a',
      events: [
        _event(
          id: 'early',
          start: DateTime(2026, 9, 8, 0, 30),
          recurrence: EventRecurrence.weekly,
          reminder: EventReminder.oneHourBefore,
        ),
      ],
      location: helsinki,
      now: tz.TZDateTime(helsinki, 2026, 9, 1),
    );

    expect(
      plan.requests.first.scheduledDate,
      tz.TZDateTime(helsinki, 2026, 9, 7, 23, 30),
    );
  });

  test('normalizes a spring-forward gap to the first valid local time', () {
    final plan = planner.build(
      accountId: 'account-a',
      events: [
        _event(
          id: 'dst-gap',
          start: DateTime(2026, 3, 22, 3, 30),
          recurrence: EventRecurrence.weekly,
          reminder: EventReminder.atStart,
        ),
      ],
      location: helsinki,
      now: tz.TZDateTime(helsinki, 2026, 3, 23),
    );

    final gapOccurrence = plan.requests.firstWhere(
      (request) =>
          request.occurrenceStart.year == 2026 &&
          request.occurrenceStart.month == 3 &&
          request.occurrenceStart.day == 29,
    );
    expect(gapOccurrence.occurrenceStart.hour, 4);
    expect(gapOccurrence.occurrenceStart.minute, 30);
  });

  test('uses the first occurrence of an ambiguous fall-back time', () {
    final plan = planner.build(
      accountId: 'account-a',
      events: [
        _event(
          id: 'dst-overlap',
          start: DateTime(2026, 10, 18, 3, 30),
          recurrence: EventRecurrence.weekly,
          reminder: EventReminder.atStart,
        ),
      ],
      location: helsinki,
      now: tz.TZDateTime(helsinki, 2026, 10, 19),
    );

    final overlapOccurrence = plan.requests.firstWhere(
      (request) =>
          request.occurrenceStart.year == 2026 &&
          request.occurrenceStart.month == 10 &&
          request.occurrenceStart.day == 25,
    );
    expect(overlapOccurrence.occurrenceStart.hour, 3);
    expect(overlapOccurrence.occurrenceStart.minute, 30);
    expect(
      overlapOccurrence.occurrenceStart.timeZoneOffset,
      const Duration(hours: 3),
    );
  });

  test('identifiers are stable, account-scoped, and occurrence-scoped', () {
    final first = macOSEventReminderNotificationId(
      accountId: 'account-a',
      eventId: 'event-a',
      occurrenceKey: '2026-09-06T09:00:00.000000',
    );

    expect(
      macOSEventReminderNotificationId(
        accountId: 'account-a',
        eventId: 'event-a',
        occurrenceKey: '2026-09-06T09:00:00.000000',
      ),
      first,
    );
    expect(
      macOSEventReminderNotificationId(
        accountId: 'account-b',
        eventId: 'event-a',
        occurrenceKey: '2026-09-06T09:00:00.000000',
      ),
      isNot(first),
    );
    expect(
      macOSEventReminderNotificationId(
        accountId: 'account-a',
        eventId: 'event-a',
        occurrenceKey: '2026-09-07T09:00:00.000000',
      ),
      isNot(first),
    );
  });

  test('omits disabled and already-passed reminders', () {
    final plan = planner.build(
      accountId: 'account-a',
      events: [
        _event(
          id: 'disabled',
          start: DateTime(2026, 9, 7, 9),
          recurrence: EventRecurrence.none,
          reminder: EventReminder.none,
        ),
        _event(
          id: 'past',
          start: DateTime(2026, 9, 6, 8),
          recurrence: EventRecurrence.none,
          reminder: EventReminder.atStart,
        ),
      ],
      location: helsinki,
      now: tz.TZDateTime(helsinki, 2026, 9, 6, 9),
    );

    expect(plan.requests, isEmpty);
    expect(plan.waitingForCapacity, 0);
  });
}

Event _event({
  required String id,
  required DateTime start,
  required EventRecurrence recurrence,
  EventReminder reminder = EventReminder.fifteenMinutesBefore,
}) {
  return Event(
    id: id,
    title: 'Event $id',
    startTime: start,
    endTime: start.add(const Duration(hours: 1)),
    reminder: reminder,
    recurrence: recurrence,
  );
}
