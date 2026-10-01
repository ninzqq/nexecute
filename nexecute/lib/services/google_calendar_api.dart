import 'package:nexecute/domain/calendar/calendar_query_range.dart';

enum GoogleCalendarApiFailureKind {
  unauthorized,
  forbidden,
  rateLimited,
  transient,
  malformedResponse,
}

final class GoogleCalendarApiException implements Exception {
  const GoogleCalendarApiException(this.kind);

  final GoogleCalendarApiFailureKind kind;

  @override
  String toString() => 'Google Calendar API failed: ${kind.name}';
}

final class GoogleCalendarInfo {
  const GoogleCalendarInfo({
    required this.id,
    required this.name,
    required this.accessRole,
    required this.defaultSelected,
    this.colorValue,
    this.timeZone,
    this.isPrimary = false,
  });

  final String id;
  final String name;
  final String accessRole;
  final bool defaultSelected;
  final int? colorValue;
  final String? timeZone;
  final bool isPrimary;
}

final class GoogleCalendarRemoteEvent {
  const GoogleCalendarRemoteEvent({
    required this.eventId,
    required this.occurrenceKey,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
    this.sourceTimeZone,
    this.externalUrl,
  });

  final String eventId;
  final String occurrenceKey;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final String? sourceTimeZone;
  final Uri? externalUrl;
}

final class GoogleCalendarPage<T> {
  GoogleCalendarPage({required List<T> items, this.nextPageToken})
    : items = List.unmodifiable(items);

  final List<T> items;
  final String? nextPageToken;
}

abstract interface class GoogleCalendarApiGateway {
  Future<GoogleCalendarPage<GoogleCalendarInfo>> listCalendars({
    required String accessToken,
    String? pageToken,
  });

  Future<GoogleCalendarPage<GoogleCalendarRemoteEvent>> listEvents({
    required String accessToken,
    required String calendarId,
    required CalendarQueryRange range,
    String? pageToken,
  });

  void close();
}
