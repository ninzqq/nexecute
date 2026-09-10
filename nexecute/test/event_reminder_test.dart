import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/services/event_reminder_scheduler.dart';
import 'package:test/test.dart';

void main() {
  test('defaults new events to a reminder fifteen minutes before', () {
    expect(defaultEventReminder, EventReminder.fifteenMinutesBefore);
  });

  test('calculates the reminder time from the event start', () {
    final start = DateTime(2026, 9, 1, 10);

    expect(
      EventReminder.fifteenMinutesBefore.scheduledTime(start),
      DateTime(2026, 9, 1, 9, 45),
    );
    expect(EventReminder.atStart.scheduledTime(start), start);
    expect(EventReminder.none.scheduledTime(start), isNull);
  });

  test('restores supported stored minute values', () {
    expect(EventReminder.fromMinutesBefore(60), EventReminder.oneHourBefore);
    expect(EventReminder.fromMinutesBefore(null), EventReminder.none);
    expect(EventReminder.fromMinutesBefore(123), EventReminder.none);
  });

  test('builds evening-before and morning-of all-day reminders', () {
    final reminders = eventReminderNotifications(
      Event(
        id: 'conference',
        title: 'Conference',
        startTime: DateTime(2026, 10, 1),
        endTime: DateTime(2026, 10, 2),
        isAllDay: true,
      ),
    );

    expect(reminders, hasLength(2));
    expect(reminders[0].scheduledTime, DateTime(2026, 9, 30, 21));
    expect(reminders[0].title, 'Conference Tomorrow');
    expect(reminders[0].body, 'All-day event');
    expect(reminders[1].scheduledTime, DateTime(2026, 10, 1, 9));
    expect(reminders[1].title, 'Conference');
    expect(reminders[1].body, 'Today');
  });

  test('does not build all-day reminders when reminders are disabled', () {
    final reminders = eventReminderNotifications(
      Event(
        id: 'day-off',
        title: 'Day off',
        startTime: DateTime(2026, 10, 1),
        endTime: DateTime(2026, 10, 2),
        isAllDay: true,
        reminder: EventReminder.none,
      ),
    );

    expect(reminders, isEmpty);
  });
}
