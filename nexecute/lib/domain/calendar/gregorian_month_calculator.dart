import 'calendar_month.dart';
import 'calendar_week.dart';
import 'iso_week_calculator.dart';
import 'month_calculator.dart';
import 'week_calculator.dart';

class GregorianMonthCalculator implements MonthCalculator {
  GregorianMonthCalculator({WeekCalculator? weekCalculator})
    : _weekCalculator = weekCalculator ?? IsoWeekCalculator();

  final WeekCalculator _weekCalculator;

  @override
  CalendarMonth fromDate(DateTime date) {
    final start = DateTime(date.year, date.month);
    final end = DateTime(date.year, date.month + 1, 0);
    final weeks = <CalendarWeek>[];

    var week = _weekCalculator.fromDate(start);
    while (!week.start.isAfter(end)) {
      weeks.add(week);
      final nextWeek = _weekCalculator.nextWeek(week);

      if (!nextWeek.start.isAfter(week.start)) {
        throw StateError(
          'Week calculator did not advance beyond ${week.start}.',
        );
      }
      if (weeks.length > 6) {
        throw StateError('A Gregorian month cannot span more than six weeks.');
      }

      week = nextWeek;
    }

    return CalendarMonth(
      year: start.year,
      month: start.month,
      start: start,
      end: end,
      weeks: weeks,
    );
  }

  @override
  CalendarMonth nextMonth(CalendarMonth month) =>
      fromDate(DateTime(month.year, month.month + 1));

  @override
  CalendarMonth previousMonth(CalendarMonth month) =>
      fromDate(DateTime(month.year, month.month - 1));
}
