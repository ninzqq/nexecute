enum EventReminder {
  none(null),
  atStart(0),
  fiveMinutesBefore(5),
  tenMinutesBefore(10),
  fifteenMinutesBefore(15),
  thirtyMinutesBefore(30),
  oneHourBefore(60),
  twoHoursBefore(120),
  oneDayBefore(1440),
  oneWeekBefore(10080);

  const EventReminder(this.minutesBefore);

  final int? minutesBefore;

  DateTime? scheduledTime(DateTime eventStart) {
    final minutes = minutesBefore;
    return minutes == null
        ? null
        : eventStart.subtract(Duration(minutes: minutes));
  }

  static EventReminder fromMinutesBefore(Object? value) {
    if (value == null) return none;
    return EventReminder.values.firstWhere(
      (reminder) => reminder.minutesBefore == value,
      orElse: () => none,
    );
  }
}

const defaultEventReminder = EventReminder.fifteenMinutesBefore;
