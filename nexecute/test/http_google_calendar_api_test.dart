import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/services/google_calendar_api.dart';
import 'package:nexecute/services/http_google_calendar_api.dart';

void main() {
  test('requests and decodes readable visible calendars', () async {
    late http.Request sent;
    final api = HttpGoogleCalendarApi(
      client: MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'nextPageToken': 'next',
            'items': [
              {
                'id': 'primary@example.com',
                'summary': 'Calendar',
                'summaryOverride': 'Mine',
                'accessRole': 'owner',
                'selected': true,
                'primary': true,
                'backgroundColor': '#12abEF',
                'timeZone': 'Europe/Helsinki',
              },
              {
                'id': 'hidden',
                'summary': 'Hidden',
                'accessRole': 'reader',
                'hidden': true,
              },
              {
                'id': 'busy',
                'summary': 'Busy only',
                'accessRole': 'freeBusyReader',
              },
            ],
          }),
          200,
        );
      }),
    );

    final page = await api.listCalendars(
      accessToken: 'token',
      pageToken: 'page',
    );

    expect(sent.method, 'GET');
    expect(sent.url.path, '/calendar/v3/users/me/calendarList');
    expect(sent.headers['authorization'], 'Bearer token');
    expect(sent.url.queryParameters['pageToken'], 'page');
    expect(sent.url.queryParameters['colorRgbFormat'], 'true');
    expect(sent.url.queryParameters['showDeleted'], 'false');
    expect(sent.url.queryParameters['showHidden'], 'false');
    expect(page.nextPageToken, 'next');
    expect(page.items, hasLength(1));
    expect(page.items.single.name, 'Mine');
    expect(page.items.single.colorValue, 0xff12abef);
    expect(page.items.single.timeZone, 'Europe/Helsinki');
    expect(page.items.single.defaultSelected, isTrue);
    expect(page.items.single.isPrimary, isTrue);
  });

  test('bounds and normalizes timed and all-day events', () async {
    late http.Request sent;
    final api = HttpGoogleCalendarApi(
      client: MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'timed',
                'status': 'confirmed',
                'summary': 'Offset event',
                'description': 'Details',
                'htmlLink': 'https://calendar.google.com/event?id=1',
                'start': {
                  'dateTime': '2026-10-01T12:30:00+03:00',
                  'timeZone': 'Europe/Helsinki',
                },
                'end': {'dateTime': '2026-10-01T13:30:00+03:00'},
                'originalStartTime': {'dateTime': '2026-10-01T12:30:00+03:00'},
              },
              {
                'id': 'all-day',
                'status': 'confirmed',
                'start': {'date': '2026-10-02'},
                'end': {'date': '2026-10-05'},
                'htmlLink': 'http://insecure.example/event',
              },
              {'id': 'cancelled', 'status': 'cancelled'},
            ],
          }),
          200,
        );
      }),
    );
    final range = CalendarQueryRange(
      startInclusive: DateTime.utc(2026, 10),
      endExclusive: DateTime.utc(2026, 11),
    );

    final page = await api.listEvents(
      accessToken: 'secret',
      calendarId: 'calendar/id@example.com',
      range: range,
    );

    expect(sent.url.pathSegments, [
      'calendar',
      'v3',
      'calendars',
      'calendar/id@example.com',
      'events',
    ]);
    expect(sent.url.queryParameters['timeMin'], '2026-10-01T00:00:00.000Z');
    expect(sent.url.queryParameters['timeMax'], '2026-11-01T00:00:00.000Z');
    expect(sent.url.queryParameters['singleEvents'], 'true');
    expect(sent.url.queryParameters['orderBy'], 'startTime');
    expect(sent.url.queryParameters['showDeleted'], 'false');
    expect(page.items, hasLength(2));
    expect(page.items.first.startTime, DateTime.utc(2026, 10, 1, 9, 30));
    expect(page.items.first.endTime, DateTime.utc(2026, 10, 1, 10, 30));
    expect(page.items.first.occurrenceKey, '2026-10-01T09:30:00.000Z');
    expect(page.items.first.sourceTimeZone, 'Europe/Helsinki');
    expect(page.items.first.externalUrl?.scheme, 'https');
    expect(page.items.last.occurrenceKey, 'all-day');
    expect(page.items.last.startTime, DateTime(2026, 10, 2));
    expect(page.items.last.endTime, DateTime(2026, 10, 4));
    expect(page.items.last.isAllDay, isTrue);
    expect(page.items.last.externalUrl, isNull);
  });

  test('retries quota responses at deterministic bounded delays', () async {
    var attempts = 0;
    final delays = <Duration>[];
    final api = HttpGoogleCalendarApi(
      client: MockClient((_) async {
        attempts += 1;
        return http.Response(
          jsonEncode({
            'error': {
              'errors': [
                {'reason': 'userRateLimitExceeded'},
              ],
            },
          }),
          403,
        );
      }),
      delay: (duration) async => delays.add(duration),
    );

    await expectLater(
      api.listCalendars(accessToken: 'private-token'),
      throwsA(
        isA<GoogleCalendarApiException>().having(
          (error) => error.kind,
          'kind',
          GoogleCalendarApiFailureKind.rateLimited,
        ),
      ),
    );
    expect(attempts, 3);
    expect(delays, const [Duration(seconds: 1), Duration(seconds: 2)]);
  });

  test('classifies failures without exposing response or token data', () async {
    for (final entry in <(int, GoogleCalendarApiFailureKind)>[
      (401, GoogleCalendarApiFailureKind.unauthorized),
      (403, GoogleCalendarApiFailureKind.forbidden),
      (429, GoogleCalendarApiFailureKind.rateLimited),
      (503, GoogleCalendarApiFailureKind.transient),
    ]) {
      final api = HttpGoogleCalendarApi(
        client: MockClient(
          (_) async => http.Response('payload secret-token', entry.$1),
        ),
        delay: (_) async {},
      );
      final error = await api
          .listCalendars(accessToken: 'secret-token')
          .then<Object?>((_) => null, onError: (Object error) => error);
      expect((error as GoogleCalendarApiException).kind, entry.$2);
      expect(error.toString(), isNot(contains('payload')));
      expect(error.toString(), isNot(contains('secret-token')));
    }
  });

  test(
    'maps malformed JSON and invalid field types to malformed response',
    () async {
      for (final body in [
        'not-json',
        '{"items":"wrong"}',
        '{"items":[{"id":1}]}',
      ]) {
        final api = HttpGoogleCalendarApi(
          client: MockClient((_) async => http.Response(body, 200)),
        );
        await expectLater(
          api.listCalendars(accessToken: 'token'),
          throwsA(
            isA<GoogleCalendarApiException>().having(
              (error) => error.kind,
              'kind',
              GoogleCalendarApiFailureKind.malformedResponse,
            ),
          ),
        );
      }
    },
  );

  test('rejects malformed UTF-8 and non-RFC3339 event times', () async {
    final responses = <http.Response>[
      http.Response.bytes([0xc3, 0x28], 200),
      http.Response(
        jsonEncode({
          'items': [
            {
              'id': 'event',
              'status': 'confirmed',
              'start': {'dateTime': '2026-10-01 12:00:00Z'},
              'end': {'dateTime': '2026-10-01T13:00:00Z'},
            },
          ],
        }),
        200,
      ),
    ];
    final api = HttpGoogleCalendarApi(
      client: MockClient((_) async => responses.removeAt(0)),
    );

    await expectLater(
      api.listCalendars(accessToken: 'token'),
      _malformedResponse,
    );
    await expectLater(
      api.listEvents(
        accessToken: 'token',
        calendarId: 'calendar',
        range: CalendarQueryRange(
          startInclusive: DateTime.utc(2026, 10),
          endExclusive: DateTime.utc(2026, 11),
        ),
      ),
      _malformedResponse,
    );
  });

  test('does not close an injected client', () {
    final client = _CloseTrackingClient();
    final api = HttpGoogleCalendarApi(client: client);

    api.close();
    api.close();

    expect(client.closed, isFalse);
  });

  test('accepts an omitted items field as an empty page', () async {
    final api = HttpGoogleCalendarApi(
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    final page = await api.listCalendars(accessToken: 'token');

    expect(page.items, isEmpty);
    expect(page.nextPageToken, isNull);
  });

  test('retries transient transport failures with bounded delays', () async {
    var attempts = 0;
    final delays = <Duration>[];
    final api = HttpGoogleCalendarApi(
      client: MockClient((_) async {
        attempts += 1;
        if (attempts < 3) throw http.ClientException('private failure');
        return http.Response('{"items":[]}', 200);
      }),
      delay: (duration) async => delays.add(duration),
    );

    final page = await api.listCalendars(accessToken: 'secret-token');

    expect(page.items, isEmpty);
    expect(attempts, 3);
    expect(delays, const [Duration(seconds: 1), Duration(seconds: 2)]);
  });

  test('classifies an exhausted transport failure as network', () async {
    final api = HttpGoogleCalendarApi(
      client: MockClient((_) async => throw http.ClientException('private')),
      delay: (_) async {},
    );

    await expectLater(
      api.listCalendars(accessToken: 'secret-token'),
      throwsA(
        isA<GoogleCalendarApiException>().having(
          (error) => error.kind,
          'kind',
          GoogleCalendarApiFailureKind.network,
        ),
      ),
    );
  });

  test('preserves DST offsets when normalizing RFC3339 instants', () async {
    final api = HttpGoogleCalendarApi(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'summer',
                'status': 'confirmed',
                'start': {'dateTime': '2026-10-24T09:00:00+03:00'},
                'end': {'dateTime': '2026-10-24T10:00:00+03:00'},
              },
              {
                'id': 'winter',
                'status': 'confirmed',
                'start': {'dateTime': '2026-10-26T09:00:00+02:00'},
                'end': {'dateTime': '2026-10-26T10:00:00+02:00'},
              },
            ],
          }),
          200,
        ),
      ),
    );

    final page = await api.listEvents(
      accessToken: 'token',
      calendarId: 'calendar',
      range: CalendarQueryRange(
        startInclusive: DateTime.utc(2026, 10, 20),
        endExclusive: DateTime.utc(2026, 10, 30),
      ),
    );

    expect(page.items[0].startTime, DateTime.utc(2026, 10, 24, 6));
    expect(page.items[1].startTime, DateTime.utc(2026, 10, 26, 7));
  });
}

final _malformedResponse = throwsA(
  isA<GoogleCalendarApiException>().having(
    (error) => error.kind,
    'kind',
    GoogleCalendarApiFailureKind.malformedResponse,
  ),
);

final class _CloseTrackingClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw UnimplementedError();

  @override
  void close() {
    closed = true;
    super.close();
  }
}
