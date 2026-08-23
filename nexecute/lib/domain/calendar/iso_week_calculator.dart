import 'calendar_day.dart';
import 'calendar_week.dart';
import 'week_calculator.dart';

class IsoWeekCalculator implements WeekCalculator {
  @override
  CalendarWeek fromDate(DateTime date) {
    final monday = _startOfWeek(date);
    final sunday = _addCalendarDays(monday, 6);

    final days = List.generate(7, (index) {
      final dayDate = _addCalendarDays(monday, index);
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
    return fromDate(_addCalendarDays(week.start, 7));
  }

  @override
  CalendarWeek previousWeek(CalendarWeek week) {
    return fromDate(_addCalendarDays(week.start, -7));
  }

  // ---------- helpers ----------

  DateTime _startOfWeek(DateTime date) {
    final normalized = _dateOnly(date);
    return _addCalendarDays(
      normalized,
      -(normalized.weekday - DateTime.monday),
    );
  }

  int _isoWeekNumber(DateTime date) {
    final thursday = _addCalendarDays(date, 4 - date.weekday);

    final firstThursdayOfYear = _newDate(thursday, thursday.year, 1, 4);
    final firstWeekStart = _addCalendarDays(
      firstThursdayOfYear,
      -(firstThursdayOfYear.weekday - DateTime.monday),
    );

    // Compare civil dates in UTC so daylight-saving changes cannot skew the
    // number of elapsed calendar days.
    final elapsedDays =
        DateTime.utc(thursday.year, thursday.month, thursday.day)
            .difference(
              DateTime.utc(
                firstWeekStart.year,
                firstWeekStart.month,
                firstWeekStart.day,
              ),
            )
            .inDays;

    return (elapsedDays ~/ 7) + 1;
  }

  int _isoYear(DateTime date) {
    final thursday = _addCalendarDays(date, 4 - date.weekday);
    return thursday.year;
  }

  DateTime _dateOnly(DateTime date) =>
      _newDate(date, date.year, date.month, date.day);

  DateTime _addCalendarDays(DateTime date, int days) =>
      _newDate(date, date.year, date.month, date.day + days);

  DateTime _newDate(DateTime source, int year, int month, int day) =>
      source.isUtc
          ? DateTime.utc(year, month, day)
          : DateTime(year, month, day);
}
