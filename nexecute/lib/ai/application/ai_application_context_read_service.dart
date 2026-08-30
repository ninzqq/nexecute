import 'dart:async';

import 'package:nexecute/ai/application/ai_application_context_builder.dart';
import 'package:nexecute/ai/application/ai_application_context_read_contract.dart';
import 'package:nexecute/ai/domain/ai_application_context.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/repositories/note_repository.dart';
import 'package:nexecute/repositories/todo_repository.dart';
import 'package:nexecute/search/search_matcher.dart';

export 'ai_application_context_read_contract.dart';

class RepositoryBackedAiApplicationContextReadService
    implements AiApplicationContextReadService {
  RepositoryBackedAiApplicationContextReadService({
    required TodoRepository todoRepository,
    required EventRepository eventRepository,
    required NoteRepository noteRepository,
    DateTime Function()? clock,
    this.readTimeout = AiApplicationContextReadLimits.defaultReadTimeout,
  }) : _todoRepository = todoRepository,
       _eventRepository = eventRepository,
       _noteRepository = noteRepository,
       _clock = clock ?? DateTime.now {
    if (readTimeout <= Duration.zero) {
      throw ArgumentError.value(
        readTimeout,
        'readTimeout',
        'must be greater than zero',
      );
    }
  }

  final TodoRepository _todoRepository;
  final EventRepository _eventRepository;
  final NoteRepository _noteRepository;
  final DateTime Function() _clock;
  final Duration readTimeout;

  @override
  Future<AiApplicationContextEnvelope> listTasks({
    required AiApplicationReadScope scope,
    int limit = AiApplicationContextLimits.maxActiveTasks,
  }) async {
    if (!scope.allowActiveTasks) {
      throw const AiApplicationContextReadException(
        AiApplicationContextReadErrorCode.unauthorized,
        'Active-task access was not authorized for this request.',
      );
    }
    _validateResultLimit(
      limit,
      maximum: AiApplicationContextLimits.maxActiveTasks,
    );
    final tasks = await _readList(_todoRepository.watchTodos);
    final orderedTasks = [...tasks]..sort((first, second) {
      final updated = second.updatedAt.compareTo(first.updatedAt);
      return updated != 0 ? updated : first.id.compareTo(second.id);
    });
    return AiApplicationContextBuilder.build(
      generatedAt: _clock(),
      includeActiveTasks: true,
      tasks: orderedTasks,
      taskLimit: limit,
    );
  }

  @override
  Future<AiApplicationContextEnvelope> eventsForDateRange({
    required AiApplicationReadScope scope,
    required CalendarQueryRange range,
    int limit = AiApplicationContextLimits.maxEvents,
  }) async {
    _validateRangeLength(range);
    if (!scope.allowsEventRange(range)) {
      throw const AiApplicationContextReadException(
        AiApplicationContextReadErrorCode.unauthorized,
        'The event range is outside the range authorized for this request.',
      );
    }
    _validateResultLimit(limit, maximum: AiApplicationContextLimits.maxEvents);
    final events = await _readList(() => _eventRepository.watchEvents(range));
    return AiApplicationContextBuilder.build(
      generatedAt: _clock(),
      eventRange: range,
      events: events,
      eventLimit: limit,
    );
  }

  @override
  Future<AiNoteSearchContextResult> searchNotes({
    required AiApplicationReadScope scope,
    required String query,
    int limit = AiApplicationContextReadLimits.maxSearchResults,
  }) async {
    if (!scope.allowNoteSearch) {
      throw const AiApplicationContextReadException(
        AiApplicationContextReadErrorCode.unauthorized,
        'Note search was not authorized for this request.',
      );
    }
    final normalizedQuery = normalizeSearchQuery(query);
    if (normalizedQuery.length <
            AiApplicationContextReadLimits.minSearchQueryCharacters ||
        normalizedQuery.length >
            AiApplicationContextReadLimits.maxSearchQueryCharacters) {
      throw const AiApplicationContextReadException(
        AiApplicationContextReadErrorCode.invalidArgument,
        'The note search query has an unsupported length.',
      );
    }
    _validateResultLimit(
      limit,
      maximum: AiApplicationContextReadLimits.maxSearchResults,
    );
    final notes = await _readList(_noteRepository.watchNotes);
    final matches =
        notes
            .where(
              (note) =>
                  !note.trashed && noteMatchesSearch(note, normalizedQuery),
            )
            .toList()
          ..sort((first, second) {
            final updated = second.updatedAt.compareTo(first.updatedAt);
            return updated != 0 ? updated : first.id.compareTo(second.id);
          });
    final includedMatches = matches.take(limit).toList(growable: false);
    final context = AiApplicationContextBuilder.build(
      generatedAt: _clock(),
      selectedNotes: matches,
      includeSelectedNotes: true,
      selectedNoteLimit: limit,
    );
    return AiNoteSearchContextResult(
      context: context,
      sourceNoteIds: [for (final note in includedMatches) note.id],
    );
  }

  @override
  Future<AiApplicationContextEnvelope> getNote({
    required AiApplicationReadScope scope,
    required String noteId,
  }) async {
    _validateIdentifier(noteId, argumentName: 'noteId');
    if (!scope.allowedNoteIds.contains(noteId)) {
      throw const AiApplicationContextReadException(
        AiApplicationContextReadErrorCode.unauthorized,
        'This note was not authorized for the request.',
      );
    }
    final notes = await _readList(_noteRepository.watchNotes);
    Quicxec? match;
    for (final note in notes) {
      if (note.id == noteId && !note.trashed) {
        match = note;
        break;
      }
    }
    if (match == null) {
      throw const AiApplicationContextReadException(
        AiApplicationContextReadErrorCode.notFound,
        'The authorized note is no longer available.',
      );
    }
    return AiApplicationContextBuilder.build(
      generatedAt: _clock(),
      selectedNotes: [match],
      includeSelectedNotes: true,
      selectedNoteLimit: 1,
    );
  }

  Future<List<T>> _readList<T>(
    Stream<DataState<List<T>>> Function() load,
  ) async {
    try {
      final state = await load()
          .firstWhere((state) => state is! DataLoading<List<T>>)
          .timeout(readTimeout);
      return switch (state) {
        DataReady<List<T>>(:final value) ||
        DataEmpty<List<T>>(:final value) => value,
        DataUnauthenticated<List<T>>() =>
          throw const AiApplicationContextReadException(
            AiApplicationContextReadErrorCode.unauthenticated,
            'Sign in before sharing application context.',
          ),
        DataFailure<List<T>>() =>
          throw const AiApplicationContextReadException(
            AiApplicationContextReadErrorCode.unavailable,
            'Application context could not be loaded.',
          ),
        DataLoading<List<T>>() => throw StateError('Unreachable state.'),
      };
    } on AiApplicationContextReadException {
      rethrow;
    } on TimeoutException {
      throw const AiApplicationContextReadException(
        AiApplicationContextReadErrorCode.timeout,
        'Application context did not load in time.',
      );
    } catch (_) {
      throw const AiApplicationContextReadException(
        AiApplicationContextReadErrorCode.unavailable,
        'Application context could not be loaded.',
      );
    }
  }
}

void _validateResultLimit(int limit, {required int maximum}) {
  if (limit < 1 || limit > maximum) {
    throw AiApplicationContextReadException(
      AiApplicationContextReadErrorCode.invalidArgument,
      'The result limit must be between 1 and $maximum.',
    );
  }
}

void _validateRangeLength(CalendarQueryRange range) {
  if (_isValidRangeLength(range)) return;
  throw const AiApplicationContextReadException(
    AiApplicationContextReadErrorCode.invalidArgument,
    'The event range must be positive and no longer than 31 calendar days.',
  );
}

bool _isValidRangeLength(CalendarQueryRange range) {
  if (!range.endExclusive.isAfter(range.startInclusive)) return false;
  final startDay = DateTime.utc(
    range.startInclusive.year,
    range.startInclusive.month,
    range.startInclusive.day,
  );
  final endDay = DateTime.utc(
    range.endExclusive.year,
    range.endExclusive.month,
    range.endExclusive.day,
  );
  return endDay.difference(startDay).inDays <=
      AiApplicationContextLimits.maxEventRangeDays;
}

void _validateIdentifier(String id, {required String argumentName}) {
  if (_isValidIdentifier(id)) return;
  throw AiApplicationContextReadException(
    AiApplicationContextReadErrorCode.invalidArgument,
    '$argumentName is not a valid application identifier.',
  );
}

bool _isValidIdentifier(String id) {
  final trimmed = id.trim();
  return id == trimmed &&
      trimmed.isNotEmpty &&
      trimmed.length <=
          AiApplicationContextReadLimits.maxIdentifierCharacters &&
      RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(trimmed);
}
