import 'calendar_day.dart';

class CalendarWeek {
  final int year;
  final int weekNumber;
  final DateTime start; // Monday
  final DateTime end; // Sunday
  final List<CalendarDay> days;

  CalendarWeek({
    required this.year,
    required this.weekNumber,
    required this.start,
    required this.end,
    required this.days,
  });

  CalendarDay dayFor(DateTime date) {
    return days.firstWhere(
      (d) =>
          d.date.year == date.year &&
          d.date.month == date.month &&
          d.date.day == date.day,
    );
  }
}
