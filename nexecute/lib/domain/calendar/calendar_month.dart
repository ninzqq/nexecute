import 'calendar_day.dart';
import 'calendar_week.dart';

class CalendarMonth {
  final int year;
  final int month;
  final DateTime start;
  final DateTime end;
  final List<CalendarWeek> weeks;

  CalendarMonth({
    required this.year,
    required this.month,
    required this.start,
    required this.end,
    required this.weeks,
  });

  List<CalendarDay> get days => [for (final week in weeks) ...week.days];

  bool contains(DateTime date) => date.year == year && date.month == month;
}
