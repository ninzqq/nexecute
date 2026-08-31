import 'dart:math' as math;

import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_recurrence.dart';

List<Event> expandRecurringEvent(Event event, CalendarQueryRange range) {
  if (!event.recurrence.repeats) {
    return range.overlaps(start: event.startTime, end: event.endTime)
        ? [event]
        : const [];
  }

  final firstIndex = _firstUsefulOccurrenceIndex(event, range.startInclusive);
  final occurrences = <Event>[];
  for (var index = firstIndex; ; index++) {
    final occurrenceStart = _occurrenceStart(event, index);
    if (!occurrenceStart.isBefore(range.endExclusive)) break;

    final occurrenceEnd = _occurrenceEnd(event, occurrenceStart);
    if (range.overlaps(start: occurrenceStart, end: occurrenceEnd)) {
      occurrences.add(
        Event(
          id: event.id,
          title: event.title,
          description: event.description,
          startTime: occurrenceStart,
          endTime: occurrenceEnd,
          isAllDay: event.isAllDay,
          tags: event.tags,
          reminder: event.reminder,
          recurrence: event.recurrence,
          recurrenceSeriesStartTime: event.seriesStartTime,
          recurrenceSeriesEndTime: event.seriesEndTime,
        ),
      );
    }
  }
  return occurrences;
}

List<Event> expandRecurringEvents(
  Iterable<Event> events,
  CalendarQueryRange range,
) {
  final occurrences = [
    for (final event in events) ...expandRecurringEvent(event, range),
  ]..sort((first, second) => first.startTime.compareTo(second.startTime));
  return occurrences;
}

int _firstUsefulOccurrenceIndex(Event event, DateTime rangeStart) {
  final eventSpanDays = math.max(
    0,
    _dateAsUtc(
      event.seriesEndTime,
    ).difference(_dateAsUtc(event.seriesStartTime)).inDays,
  );
  final adjustedRangeStart = _addCalendarDays(rangeStart, -eventSpanDays - 1);
  final start = event.seriesStartTime;

  return math.max(0, switch (event.recurrence) {
    EventRecurrence.none => 0,
    EventRecurrence.daily =>
      _dateAsUtc(adjustedRangeStart).difference(_dateAsUtc(start)).inDays,
    EventRecurrence.weekly =>
      _dateAsUtc(adjustedRangeStart).difference(_dateAsUtc(start)).inDays ~/ 7 -
          1,
    EventRecurrence.monthly =>
      (adjustedRangeStart.year - start.year) * 12 +
          adjustedRangeStart.month -
          start.month -
          1,
    EventRecurrence.yearly => adjustedRangeStart.year - start.year - 1,
  });
}

DateTime _occurrenceStart(Event event, int index) {
  final start = event.seriesStartTime;
  return switch (event.recurrence) {
    EventRecurrence.none => start,
    EventRecurrence.daily => _copyWithDate(
      start,
      DateTime.utc(start.year, start.month, start.day + index),
    ),
    EventRecurrence.weekly => _copyWithDate(
      start,
      DateTime.utc(start.year, start.month, start.day + index * 7),
    ),
    EventRecurrence.monthly => _monthlyOccurrence(start, index),
    EventRecurrence.yearly => _yearlyOccurrence(start, index),
  };
}

DateTime _occurrenceEnd(Event event, DateTime occurrenceStart) {
  final seriesStart = event.seriesStartTime;
  final seriesEnd = event.seriesEndTime;
  final calendarDaySpan =
      _dateAsUtc(seriesEnd).difference(_dateAsUtc(seriesStart)).inDays;
  final occurrenceEndDate = DateTime.utc(
    occurrenceStart.year,
    occurrenceStart.month,
    occurrenceStart.day + calendarDaySpan,
  );
  return _dateTime(
    isUtc: seriesEnd.isUtc,
    year: occurrenceEndDate.year,
    month: occurrenceEndDate.month,
    day: occurrenceEndDate.day,
    hour: seriesEnd.hour,
    minute: seriesEnd.minute,
    second: seriesEnd.second,
    millisecond: seriesEnd.millisecond,
    microsecond: seriesEnd.microsecond,
  );
}

DateTime _monthlyOccurrence(DateTime start, int index) {
  final monthIndex = start.year * 12 + start.month - 1 + index;
  final year = monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final day = math.min(start.day, _daysInMonth(year, month));
  return _dateTimeLike(start, year: year, month: month, day: day);
}

DateTime _yearlyOccurrence(DateTime start, int index) {
  final year = start.year + index;
  final day = math.min(start.day, _daysInMonth(year, start.month));
  return _dateTimeLike(start, year: year, month: start.month, day: day);
}

DateTime _copyWithDate(DateTime time, DateTime date) =>
    _dateTimeLike(time, year: date.year, month: date.month, day: date.day);

DateTime _dateTimeLike(
  DateTime source, {
  required int year,
  required int month,
  required int day,
}) => _dateTime(
  isUtc: source.isUtc,
  year: year,
  month: month,
  day: day,
  hour: source.hour,
  minute: source.minute,
  second: source.second,
  millisecond: source.millisecond,
  microsecond: source.microsecond,
);

DateTime _dateTime({
  required bool isUtc,
  required int year,
  required int month,
  required int day,
  required int hour,
  required int minute,
  required int second,
  required int millisecond,
  required int microsecond,
}) =>
    isUtc
        ? DateTime.utc(
          year,
          month,
          day,
          hour,
          minute,
          second,
          millisecond,
          microsecond,
        )
        : DateTime(
          year,
          month,
          day,
          hour,
          minute,
          second,
          millisecond,
          microsecond,
        );

DateTime _dateAsUtc(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

DateTime _addCalendarDays(DateTime date, int days) =>
    date.isUtc
        ? DateTime.utc(date.year, date.month, date.day + days)
        : DateTime(date.year, date.month, date.day + days);

int _daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;
