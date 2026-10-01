import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/services/google_calendar_api.dart';
import 'package:nexecute/services/google_calendar_authorization.dart';

enum GoogleCalendarLocalStoreError {
  unavailable,
  corruptData,
  ioFailure,
  disposed,
}

final class GoogleCalendarLocalStoreException implements Exception {
  const GoogleCalendarLocalStoreException(this.error, this.message);

  final GoogleCalendarLocalStoreError error;
  final String message;

  @override
  String toString() => 'GoogleCalendarLocalStoreException: $message';
}

final class GoogleCalendarSelectionMetadata {
  GoogleCalendarSelectionMetadata({
    required List<GoogleCalendarInfo> calendars,
    required Set<String> selectedCalendarIds,
    required this.selectionEstablished,
    required this.updatedAt,
  }) : calendars = List.unmodifiable(calendars),
       selectedCalendarIds = Set.unmodifiable(selectedCalendarIds);

  final List<GoogleCalendarInfo> calendars;
  final Set<String> selectedCalendarIds;
  final bool selectionEstablished;
  final DateTime updatedAt;
}

final class GoogleCalendarCachedEvent {
  const GoogleCalendarCachedEvent({
    required this.sourceScopedId,
    required this.calendarId,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
    required this.calendarName,
    this.calendarColorValue,
    this.sourceTimeZone,
    this.externalUrl,
  });

  final String sourceScopedId;
  final String calendarId;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final String calendarName;
  final int? calendarColorValue;
  final String? sourceTimeZone;
  final Uri? externalUrl;
}

final class GoogleCalendarCachedRange {
  GoogleCalendarCachedRange({
    required this.calendarId,
    required this.range,
    required this.fetchedAt,
    required List<GoogleCalendarCachedEvent> events,
  }) : events = List.unmodifiable(events);

  final String calendarId;
  final CalendarQueryRange range;
  final DateTime fetchedAt;
  final List<GoogleCalendarCachedEvent> events;
}

final class GoogleCalendarLocalState {
  GoogleCalendarLocalState({
    this.metadata,
    required List<GoogleCalendarCachedRange> ranges,
  }) : ranges = List.unmodifiable(ranges);

  static final empty = GoogleCalendarLocalState(ranges: const []);

  final GoogleCalendarSelectionMetadata? metadata;
  final List<GoogleCalendarCachedRange> ranges;
}

abstract interface class GoogleCalendarLocalStore
    implements GoogleCalendarCacheLifecycle {
  Future<GoogleCalendarLocalState> load(GoogleCalendarCacheOwner owner);

  Future<GoogleCalendarLocalState> saveMetadata(
    GoogleCalendarCacheOwner owner,
    GoogleCalendarSelectionMetadata metadata, {
    Set<String> removeCalendarIds = const {},
  });

  Future<GoogleCalendarLocalState> replaceRanges(
    GoogleCalendarCacheOwner owner,
    List<GoogleCalendarCachedRange> replacements,
  );

  Future<GoogleCalendarLocalState> removeCalendars(
    GoogleCalendarCacheOwner owner,
    Set<String> calendarIds,
  );

  Future<void> dispose();
}
