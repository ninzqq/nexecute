import 'package:nexecute/models/event.dart';
import 'package:nexecute/ui/calendar/event_date_utils.dart';
import 'package:test/test.dart';

void main() {
  Event event(String id, DateTime start, DateTime end) =>
      Event(id: id, title: id, startTime: start, endTime: end);

  test('returns and sorts events for a day', () {
    final later = event(
      'later',
      DateTime(2026, 8, 23, 15),
      DateTime(2026, 8, 23, 16),
    );
    final earlier = event(
      'earlier',
      DateTime(2026, 8, 23, 9),
      DateTime(2026, 8, 23, 10),
    );

    expect(eventsForDay([later, earlier], DateTime(2026, 8, 23)), [
      earlier,
      later,
    ]);
  });

  test('includes a multi-day event on each covered date', () {
    final trip = event(
      'trip',
      DateTime(2026, 8, 22, 12),
      DateTime(2026, 8, 24, 12),
    );

    expect(eventsForDay([trip], DateTime(2026, 8, 23)), [trip]);
  });

  test('excludes events outside the requested date', () {
    final meeting = event(
      'meeting',
      DateTime(2026, 8, 22, 12),
      DateTime(2026, 8, 22, 13),
    );

    expect(eventsForDay([meeting], DateTime(2026, 8, 23)), isEmpty);
  });
}
