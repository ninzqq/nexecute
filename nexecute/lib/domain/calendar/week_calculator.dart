import 'calendar_week.dart';

abstract class WeekCalculator {
  CalendarWeek fromDate(DateTime date);
  CalendarWeek nextWeek(CalendarWeek week);
  CalendarWeek previousWeek(CalendarWeek week);
}
