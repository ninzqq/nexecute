import 'package:nexecute/ai/domain/ai_application_context.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';

abstract final class AiApplicationContextReadLimits {
  static const minSearchQueryCharacters = 2;
  static const maxSearchQueryCharacters = 100;
  static const maxSearchResults = AiApplicationContextLimits.maxSelectedNotes;
  static const maxIdentifierCharacters = 128;
  static const defaultReadTimeout = Duration(seconds: 30);
}

enum AiApplicationContextReadErrorCode {
  unauthorized,
  invalidArgument,
  unauthenticated,
  unavailable,
  timeout,
  notFound,
}

class AiApplicationContextReadException implements Exception {
  const AiApplicationContextReadException(this.code, this.message);

  final AiApplicationContextReadErrorCode code;
  final String message;

  @override
  String toString() => message;
}

class AiApplicationReadScope {
  AiApplicationReadScope({
    this.allowActiveTasks = false,
    this.allowNoteSearch = false,
    this.eventRange,
    Set<String> allowedNoteIds = const {},
  }) : allowedNoteIds = Set.unmodifiable(allowedNoteIds) {
    if (allowedNoteIds.length > AiApplicationContextLimits.maxSelectedNotes) {
      throw ArgumentError.value(
        allowedNoteIds.length,
        'allowedNoteIds',
        'must not contain more than '
            '${AiApplicationContextLimits.maxSelectedNotes} identifiers',
      );
    }
    for (final id in allowedNoteIds) {
      if (!_isValidIdentifier(id)) {
        throw ArgumentError.value(
          id,
          'allowedNoteIds',
          'contains an invalid application identifier',
        );
      }
    }
    final range = eventRange;
    if (range != null && !_isValidRangeLength(range)) {
      throw ArgumentError.value(
        range,
        'eventRange',
        'must be a positive range of at most '
            '${AiApplicationContextLimits.maxEventRangeDays} calendar days',
      );
    }
  }

  final bool allowActiveTasks;
  final bool allowNoteSearch;
  final CalendarQueryRange? eventRange;
  final Set<String> allowedNoteIds;

  bool allowsEventRange(CalendarQueryRange requested) {
    final authorized = eventRange;
    return authorized != null &&
        !requested.startInclusive.isBefore(authorized.startInclusive) &&
        !requested.endExclusive.isAfter(authorized.endExclusive);
  }
}

class AiNoteSearchContextResult {
  AiNoteSearchContextResult({
    required this.context,
    required List<String> sourceNoteIds,
  }) : sourceNoteIds = List.unmodifiable(sourceNoteIds);

  final AiApplicationContextEnvelope context;

  /// Trusted, application-local identifiers corresponding to the serialized
  /// note items. They are deliberately absent from [context].
  final List<String> sourceNoteIds;
}

abstract interface class AiApplicationContextReadService {
  Future<AiApplicationContextEnvelope> listTasks({
    required AiApplicationReadScope scope,
    int limit = AiApplicationContextLimits.maxActiveTasks,
  });

  Future<AiApplicationContextEnvelope> eventsForDateRange({
    required AiApplicationReadScope scope,
    required CalendarQueryRange range,
    int limit = AiApplicationContextLimits.maxEvents,
  });

  Future<AiNoteSearchContextResult> searchNotes({
    required AiApplicationReadScope scope,
    required String query,
    int limit = AiApplicationContextReadLimits.maxSearchResults,
  });

  Future<AiApplicationContextEnvelope> getNote({
    required AiApplicationReadScope scope,
    required String noteId,
  });
}

bool _isValidIdentifier(String value) =>
    value == value.trim() &&
    value.isNotEmpty &&
    value.length <= AiApplicationContextReadLimits.maxIdentifierCharacters &&
    RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value);

bool _isValidRangeLength(CalendarQueryRange range) {
  if (!range.endExclusive.isAfter(range.startInclusive)) return false;
  final localStart = DateTime.utc(
    range.startInclusive.year,
    range.startInclusive.month,
    range.startInclusive.day,
  );
  final localEnd = DateTime.utc(
    range.endExclusive.year,
    range.endExclusive.month,
    range.endExclusive.day,
  );
  final calendarDays = localEnd.difference(localStart).inDays;
  return calendarDays <= AiApplicationContextLimits.maxEventRangeDays;
}
