import 'package:nexecute/models/event_reminder.dart';
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
}
