import 'package:nexecute/models/event_reminder.dart';

extension EventReminderLabels on EventReminder {
  String get label => switch (this) {
    EventReminder.none => 'No reminder',
    EventReminder.atStart => 'At event time',
    EventReminder.fiveMinutesBefore => '5 minutes before',
    EventReminder.tenMinutesBefore => '10 minutes before',
    EventReminder.fifteenMinutesBefore => '15 minutes before',
    EventReminder.thirtyMinutesBefore => '30 minutes before',
    EventReminder.oneHourBefore => '1 hour before',
    EventReminder.twoHoursBefore => '2 hours before',
    EventReminder.oneDayBefore => '1 day before',
    EventReminder.oneWeekBefore => '1 week before',
  };
}
