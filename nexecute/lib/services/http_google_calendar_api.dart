import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/services/google_calendar_api.dart';

typedef GoogleCalendarRetryDelay = Future<void> Function(Duration duration);

final class HttpGoogleCalendarApi implements GoogleCalendarApiGateway {
  HttpGoogleCalendarApi({
    http.Client? client,
    GoogleCalendarRetryDelay? delay,
    Duration requestTimeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _delay = delay ?? Future<void>.delayed,
       _requestTimeout = requestTimeout;

  static const _calendarFields =
      'nextPageToken,items(id,summary,summaryOverride,accessRole,selected,'
      'primary,backgroundColor,timeZone,deleted,hidden)';
  static const _eventFields =
      'nextPageToken,items(id,status,summary,description,htmlLink,'
      'start(date,dateTime,timeZone),end(date,dateTime,timeZone),'
      'originalStartTime(date,dateTime,timeZone))';
  static const _retryDelays = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
  ];

  final http.Client _client;
  final bool _ownsClient;
  final GoogleCalendarRetryDelay _delay;
  final Duration _requestTimeout;
  bool _closed = false;

  @override
  Future<GoogleCalendarPage<GoogleCalendarInfo>> listCalendars({
    required String accessToken,
    String? pageToken,
  }) async {
    final uri =
        Uri.https('www.googleapis.com', '/calendar/v3/users/me/calendarList', {
          'fields': _calendarFields,
          'colorRgbFormat': 'true',
          'showDeleted': 'false',
          'showHidden': 'false',
          if (pageToken != null) 'pageToken': pageToken,
        });
    final body = await _get(uri, accessToken);
    try {
      final page = _decodePage(body);
      final calendars = <GoogleCalendarInfo>[];
      for (final value in page.items) {
        final item = _object(value);
        final id = _requiredString(item, 'id', nonEmpty: true);
        final summary = _requiredString(item, 'summary');
        final summaryOverride = _optionalString(item, 'summaryOverride');
        final accessRole = _requiredString(item, 'accessRole', nonEmpty: true);
        final selected = _optionalBool(item, 'selected') ?? false;
        final primary = _optionalBool(item, 'primary') ?? false;
        final deleted = _optionalBool(item, 'deleted') ?? false;
        final hidden = _optionalBool(item, 'hidden') ?? false;
        final color = _optionalColor(item, 'backgroundColor');
        final timeZone = _optionalString(item, 'timeZone', nonEmpty: true);

        if (deleted || hidden || !_readableRoles.contains(accessRole)) continue;
        calendars.add(
          GoogleCalendarInfo(
            id: id,
            name:
                summaryOverride != null && summaryOverride.isNotEmpty
                    ? summaryOverride
                    : summary,
            accessRole: accessRole,
            defaultSelected: selected,
            colorValue: color,
            timeZone: timeZone,
            isPrimary: primary,
          ),
        );
      }
      return GoogleCalendarPage(
        items: calendars,
        nextPageToken: page.nextPageToken,
      );
    } catch (_) {
      throw const GoogleCalendarApiException(
        GoogleCalendarApiFailureKind.malformedResponse,
      );
    }
  }

  @override
  Future<GoogleCalendarPage<GoogleCalendarRemoteEvent>> listEvents({
    required String accessToken,
    required String calendarId,
    required CalendarQueryRange range,
    String? pageToken,
  }) async {
    final uri = Uri(
      scheme: 'https',
      host: 'www.googleapis.com',
      pathSegments: ['calendar', 'v3', 'calendars', calendarId, 'events'],
      queryParameters: {
        'fields': _eventFields,
        'timeMin': range.startInclusive.toUtc().toIso8601String(),
        'timeMax': range.endExclusive.toUtc().toIso8601String(),
        'singleEvents': 'true',
        'orderBy': 'startTime',
        'showDeleted': 'false',
        if (pageToken != null) 'pageToken': pageToken,
      },
    );
    final body = await _get(uri, accessToken);
    try {
      final page = _decodePage(body);
      final events = <GoogleCalendarRemoteEvent>[];
      for (final value in page.items) {
        final item = _object(value);
        final eventId = _requiredString(item, 'id', nonEmpty: true);
        final status = _requiredString(item, 'status', nonEmpty: true);
        if (status == 'cancelled') continue;

        final start = _eventTime(_requiredObject(item, 'start'));
        final end = _eventTime(_requiredObject(item, 'end'));
        if (start.isAllDay != end.isAllDay) throw const FormatException();

        final DateTime endTime;
        if (start.isAllDay) {
          if (!end.value.isAfter(start.value)) throw const FormatException();
          endTime = DateTime(
            end.value.year,
            end.value.month,
            end.value.day - 1,
          );
        } else {
          if (!end.value.isAfter(start.value)) throw const FormatException();
          endTime = end.value;
        }

        final original = _optionalObject(item, 'originalStartTime');
        final occurrenceKey =
            original == null ? eventId : _eventTime(original).occurrenceKey;
        events.add(
          GoogleCalendarRemoteEvent(
            eventId: eventId,
            occurrenceKey: occurrenceKey,
            title: _optionalString(item, 'summary') ?? '',
            description: _optionalString(item, 'description') ?? '',
            startTime: start.value,
            endTime: endTime,
            isAllDay: start.isAllDay,
            sourceTimeZone: start.timeZone ?? end.timeZone,
            externalUrl: _httpsUri(_optionalString(item, 'htmlLink')),
          ),
        );
      }
      return GoogleCalendarPage(
        items: events,
        nextPageToken: page.nextPageToken,
      );
    } catch (_) {
      throw const GoogleCalendarApiException(
        GoogleCalendarApiFailureKind.malformedResponse,
      );
    }
  }

  Future<String> _get(Uri uri, String accessToken) async {
    for (var attempt = 0; attempt < 3; attempt += 1) {
      final http.Response response;
      try {
        if (_closed) throw StateError('Client is closed');
        response = await _client
            .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
            .timeout(_requestTimeout);
      } catch (_) {
        if (!_closed && attempt < 2) {
          await _waitBeforeRetry(attempt);
          continue;
        }
        throw const GoogleCalendarApiException(
          GoogleCalendarApiFailureKind.transient,
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          return utf8.decode(response.bodyBytes, allowMalformed: false);
        } catch (_) {
          throw const GoogleCalendarApiException(
            GoogleCalendarApiFailureKind.malformedResponse,
          );
        }
      }

      final failure = _failure(response);
      if (_isRetryable(response, failure) && attempt < 2) {
        await _waitBeforeRetry(attempt);
        continue;
      }
      throw GoogleCalendarApiException(failure);
    }
    throw const GoogleCalendarApiException(
      GoogleCalendarApiFailureKind.transient,
    );
  }

  Future<void> _waitBeforeRetry(int attempt) async {
    try {
      await _delay(_retryDelays[attempt]);
    } catch (_) {
      throw const GoogleCalendarApiException(
        GoogleCalendarApiFailureKind.transient,
      );
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    if (_ownsClient) _client.close();
  }
}

const _readableRoles = {'owner', 'writer', 'reader'};
const _quotaReasons = {
  'rateLimitExceeded',
  'userRateLimitExceeded',
  'quotaExceeded',
  'dailyLimitExceeded',
};

GoogleCalendarApiFailureKind _failure(http.Response response) {
  if (response.statusCode == 401) {
    return GoogleCalendarApiFailureKind.unauthorized;
  }
  if (response.statusCode == 403) {
    return _isQuotaResponse(response.body)
        ? GoogleCalendarApiFailureKind.rateLimited
        : GoogleCalendarApiFailureKind.forbidden;
  }
  if (response.statusCode == 429) {
    return GoogleCalendarApiFailureKind.rateLimited;
  }
  if (response.statusCode >= 500 && response.statusCode < 600) {
    return GoogleCalendarApiFailureKind.transient;
  }
  return GoogleCalendarApiFailureKind.forbidden;
}

bool _isRetryable(
  http.Response response,
  GoogleCalendarApiFailureKind failure,
) =>
    response.statusCode == 429 ||
    (response.statusCode == 403 &&
        failure == GoogleCalendarApiFailureKind.rateLimited) ||
    (response.statusCode >= 500 && response.statusCode < 600);

bool _isQuotaResponse(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return false;
    final error = decoded['error'];
    if (error is! Map<String, dynamic>) return false;
    final errors = error['errors'];
    if (errors is! List) return false;
    for (final value in errors) {
      if (value is Map<String, dynamic> &&
          _quotaReasons.contains(value['reason'])) {
        return true;
      }
    }
  } catch (_) {
    return false;
  }
  return false;
}

({List<dynamic> items, String? nextPageToken}) _decodePage(String body) {
  final decoded = jsonDecode(body);
  final object = _object(decoded);
  final items = object['items'];
  if (items != null && items is! List) throw const FormatException();
  return (
    items: items as List? ?? const [],
    nextPageToken: _optionalString(object, 'nextPageToken', nonEmpty: true),
  );
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) throw const FormatException();
  return value;
}

Map<String, dynamic> _requiredObject(Map<String, dynamic> object, String key) =>
    _object(object[key]);

Map<String, dynamic>? _optionalObject(Map<String, dynamic> object, String key) {
  final value = object[key];
  return value == null ? null : _object(value);
}

String _requiredString(
  Map<String, dynamic> object,
  String key, {
  bool nonEmpty = false,
}) {
  final value = object[key];
  if (value is! String || (nonEmpty && value.isEmpty)) {
    throw const FormatException();
  }
  return value;
}

String? _optionalString(
  Map<String, dynamic> object,
  String key, {
  bool nonEmpty = false,
}) {
  final value = object[key];
  if (value == null) return null;
  if (value is! String || (nonEmpty && value.isEmpty)) {
    throw const FormatException();
  }
  return value;
}

bool? _optionalBool(Map<String, dynamic> object, String key) {
  final value = object[key];
  if (value == null) return null;
  if (value is! bool) throw const FormatException();
  return value;
}

int? _optionalColor(Map<String, dynamic> object, String key) {
  final value = _optionalString(object, key);
  if (value == null) return null;
  if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
    throw const FormatException();
  }
  return 0xff000000 | int.parse(value.substring(1), radix: 16);
}

({DateTime value, bool isAllDay, String? timeZone, String occurrenceKey})
_eventTime(Map<String, dynamic> object) {
  final date = _optionalString(object, 'date');
  final dateTime = _optionalString(object, 'dateTime');
  final timeZone = _optionalString(object, 'timeZone', nonEmpty: true);
  if ((date == null) == (dateTime == null)) throw const FormatException();

  if (date != null) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(date);
    if (match == null) throw const FormatException();
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final value = DateTime(year, month, day);
    if (value.year != year || value.month != month || value.day != day) {
      throw const FormatException();
    }
    return (
      value: value,
      isAllDay: true,
      timeZone: timeZone,
      occurrenceKey: date,
    );
  }

  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})'
    r'(?:\.\d+)?(?:Z|[+-](\d{2}):(\d{2}))$',
  ).firstMatch(dateTime!);
  if (match == null) throw const FormatException();
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6)!);
  final offsetHour = int.tryParse(match.group(7) ?? '') ?? 0;
  final offsetMinute = int.tryParse(match.group(8) ?? '') ?? 0;
  final calendarDate = DateTime.utc(year, month, day);
  if (calendarDate.year != year ||
      calendarDate.month != month ||
      calendarDate.day != day ||
      hour > 23 ||
      minute > 59 ||
      second > 59 ||
      offsetHour > 23 ||
      offsetMinute > 59) {
    throw const FormatException();
  }
  final parsed = DateTime.tryParse(dateTime);
  if (parsed == null) throw const FormatException();
  final value = parsed.toUtc();
  return (
    value: value,
    isAllDay: false,
    timeZone: timeZone,
    occurrenceKey: value.toIso8601String(),
  );
}

Uri? _httpsUri(String? source) {
  if (source == null) return null;
  final uri = Uri.tryParse(source);
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
      ? uri
      : null;
}
