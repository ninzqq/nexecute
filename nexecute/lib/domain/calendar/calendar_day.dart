import 'calendar_event.dart';

class CalendarDay {
  final DateTime date;
  final List<CalendarEvent> events;

  CalendarDay({required this.date, List<CalendarEvent>? events})
    : events = events ?? [];

  int get dayNumber => date.day;
  int get weekday => date.weekday;
  bool get isWeekend =>
      weekday == DateTime.saturday || weekday == DateTime.sunday;
}
