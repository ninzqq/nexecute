import 'calendar_month.dart';
import 'calendar_week.dart';
import 'month_calculator.dart';
import 'week_calculator.dart';

class CalendarQueryRange {
  CalendarQueryRange({required this.startInclusive, required this.endExclusive})
    : assert(endExclusive.isAfter(startInclusive));

  final DateTime startInclusive;
  final DateTime endExclusive;

  bool overlaps({required DateTime start, required DateTime end}) {
    return start.isBefore(endExclusive) && !end.isBefore(startInclusive);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarQueryRange &&
      other.startInclusive == startInclusive &&
      other.endExclusive == endExclusive;

  @override
  int get hashCode => Object.hash(startInclusive, endExclusive);
}

CalendarQueryRange monthQueryRange(
  CalendarMonth month,
  MonthCalculator calculator,
) {
  final previousMonth = calculator.previousMonth(month);
  final nextMonth = calculator.nextMonth(month);
  return CalendarQueryRange(
    startInclusive: previousMonth.weeks.first.start,
    endExclusive: _nextCalendarDay(nextMonth.weeks.last.end),
  );
}

CalendarQueryRange weekQueryRange(
  CalendarWeek week,
  WeekCalculator calculator,
) {
  final previousWeek = calculator.previousWeek(week);
  final nextWeek = calculator.nextWeek(week);
  return CalendarQueryRange(
    startInclusive: previousWeek.start,
    endExclusive: _nextCalendarDay(nextWeek.end),
  );
}

DateTime _nextCalendarDay(DateTime date) =>
    date.isUtc
        ? DateTime.utc(date.year, date.month, date.day + 1)
        : DateTime(date.year, date.month, date.day + 1);
