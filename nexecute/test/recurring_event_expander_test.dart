import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/domain/calendar/recurring_event_expander.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_recurrence.dart';
import 'package:test/test.dart';

void main() {
  test('expands daily and weekly events only inside the requested range', () {
    final range = CalendarQueryRange(
      startInclusive: DateTime(2026, 9, 8),
      endExclusive: DateTime(2026, 9, 11),
    );

    final daily = expandRecurringEvent(
      _event(
        start: DateTime(2026, 9, 1, 9),
        recurrence: EventRecurrence.daily,
      ),
      range,
    );
    final weekly = expandRecurringEvent(
      _event(
        start: DateTime(2026, 9, 1, 14),
        recurrence: EventRecurrence.weekly,
      ),
      range,
    );

    expect(
      daily.map((event) => event.startTime),
      [
        DateTime(2026, 9, 8, 9),
        DateTime(2026, 9, 9, 9),
        DateTime(2026, 9, 10, 9),
      ],
    );
    expect(weekly.single.startTime, DateTime(2026, 9, 8, 14));
  });

  test('monthly recurrence uses the last valid day in shorter months', () {
    final occurrences = expandRecurringEvent(
      _event(
        start: DateTime(2026, 1, 31, 9),
        recurrence: EventRecurrence.monthly,
      ),
      CalendarQueryRange(
        startInclusive: DateTime(2026, 2, 1),
        endExclusive: DateTime(2026, 4, 1),
      ),
    );

    expect(
      occurrences.map((event) => event.startTime),
      [DateTime(2026, 2, 28, 9), DateTime(2026, 3, 31, 9)],
    );
  });

  test('yearly recurrence supports birthdays far beyond the source year', () {
    final birthday = _event(
      start: DateTime(1990, 10, 12),
      recurrence: EventRecurrence.yearly,
      isAllDay: true,
    );

    final occurrences = expandRecurringEvent(
      birthday,
      CalendarQueryRange(
        startInclusive: DateTime(2036, 10, 1),
        endExclusive: DateTime(2036, 11, 1),
      ),
    );

    expect(occurrences.single.startTime, DateTime(2036, 10, 12));
    expect(occurrences.single.isGeneratedOccurrence, isTrue);
    expect(occurrences.single.seriesStartTime, DateTime(1990, 10, 12));
  });

  test('leap-day yearly recurrence falls on February 28 in other years', () {
    final occurrences = expandRecurringEvent(
      _event(
        start: DateTime(2024, 2, 29),
        recurrence: EventRecurrence.yearly,
        isAllDay: true,
      ),
      CalendarQueryRange(
        startInclusive: DateTime(2025, 2, 1),
        endExclusive: DateTime(2025, 3, 1),
      ),
    );

    expect(occurrences.single.startTime, DateTime(2025, 2, 28));
  });

  test('preserves a multi-day event calendar span for each occurrence', () {
    final event = Event(
      id: 'trip',
      title: 'Trip',
      startTime: DateTime(2026, 1, 31),
      endTime: DateTime(2026, 2, 2),
      isAllDay: true,
      recurrence: EventRecurrence.monthly,
    );

    final occurrence = expandRecurringEvent(
      event,
      CalendarQueryRange(
        startInclusive: DateTime(2026, 2, 1),
        endExclusive: DateTime(2026, 3, 5),
      ),
    ).last;

    expect(occurrence.startTime, DateTime(2026, 2, 28));
    expect(occurrence.endTime, DateTime(2026, 3, 2));
  });
}

Event _event({
  required DateTime start,
  required EventRecurrence recurrence,
  bool isAllDay = false,
}) => Event(
  id: 'event',
  title: 'Event',
  startTime: start,
  endTime: isAllDay ? start : start.add(const Duration(hours: 1)),
  isAllDay: isAllDay,
  recurrence: recurrence,
);
