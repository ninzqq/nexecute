import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/domain/calendar/google_calendar_event_url.dart';

void main() {
  test('accepts public Google Calendar HTTPS event URLs', () {
    final uri = Uri.parse(
      'https://calendar.google.com/calendar/event?eid=safe',
    );

    expect(safeGoogleCalendarEventUrl(uri), uri);
  });

  test('rejects non-Google, credentialed, local, and nonstandard URLs', () {
    final unsafe = [
      'http://calendar.google.com/calendar/event',
      'https://user:secret@calendar.google.com/calendar/event',
      'https://calendar.google.com:8443/calendar/event',
      'https://localhost/calendar/event',
      'https://127.0.0.1/calendar/event',
      'https://192.168.1.10/calendar/event',
      'https://calendar.google.com.evil.test/calendar/event',
    ];

    for (final value in unsafe) {
      expect(safeGoogleCalendarEventUrl(Uri.parse(value)), isNull);
    }
  });
}
