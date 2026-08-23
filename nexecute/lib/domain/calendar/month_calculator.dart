import 'calendar_month.dart';

abstract class MonthCalculator {
  CalendarMonth fromDate(DateTime date);
  CalendarMonth nextMonth(CalendarMonth month);
  CalendarMonth previousMonth(CalendarMonth month);
}
