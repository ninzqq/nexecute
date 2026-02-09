import 'calendar_day.dart';
import 'calendar_week.dart';
import 'week_calculator.dart';

class IsoWeekCalculator implements WeekCalculator {
  @override
  CalendarWeek fromDate(DateTime date) {
    final monday = _startOfWeek(date);
    final sunday = monday.add(const Duration(days: 6));

    final days = List.generate(7, (index) {
      final dayDate = monday.add(Duration(days: index));
      return CalendarDay(date: dayDate);
    });

    return CalendarWeek(
      year: _isoYear(monday),
      weekNumber: _isoWeekNumber(monday),
      start: monday,
      end: sunday,
      days: days,
    );
  }

  @override
  CalendarWeek nextWeek(CalendarWeek week) {
    return fromDate(week.start.add(const Duration(days: 7)));
  }

  @override
  CalendarWeek previousWeek(CalendarWeek week) {
    return fromDate(week.start.subtract(const Duration(days: 7)));
  }

  // ---------- helpers ----------

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(
      Duration(days: normalized.weekday - DateTime.monday),
    );
  }

  int _isoWeekNumber(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));

    final firstThursdayOfYear = DateTime(thursday.year, 1, 4);
    final firstWeekStart = firstThursdayOfYear.subtract(
      Duration(days: firstThursdayOfYear.weekday - DateTime.monday),
    );

    return ((thursday.difference(firstWeekStart).inDays) ~/ 7) + 1;
  }

  int _isoYear(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    return thursday.year;
  }
}
