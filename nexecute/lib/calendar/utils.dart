int getHashCode(DateTime key) {
  return key.day * 1000000 + key.month * 10000 + key.year;
}

/// Returns a list of [DateTime] objects from [first] to [last], inclusive.
List<DateTime> daysInRange(DateTime start, DateTime end) {
  final days = <DateTime>[];
  for (int i = 0; i <= end.difference(start).inDays; i++) {
    days.add(
      DateTime.utc(start.year, start.month, start.day).add(Duration(days: i)),
    );
  }
  return days;
}

final kToday = DateTime.now();
final kFirstDay = DateTime(2025, 1, 1);
final kLastDay = DateTime(2050, 12, 31);
