import 'package:nexecute/models/event.dart';

List<Event> eventsForDay(Iterable<Event> events, DateTime day) {
  final normalizedDay = dateOnly(day);
  final result =
      events.where((event) {
          final start = dateOnly(event.startTime);
          final end = dateOnly(event.endTime);
          return !normalizedDay.isBefore(start) && !normalizedDay.isAfter(end);
        }).toList()
        ..sort((first, second) => first.startTime.compareTo(second.startTime));

  return result;
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool isSameCalendarDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
