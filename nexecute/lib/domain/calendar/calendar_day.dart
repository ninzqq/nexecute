class CalendarDay {
  final DateTime date;

  CalendarDay({required this.date});

  int get dayNumber => date.day;
  int get weekday => date.weekday;
  bool get isWeekend =>
      weekday == DateTime.saturday || weekday == DateTime.sunday;
}
