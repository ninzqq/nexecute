import 'dart:async';

import 'package:nexecute/domain/calendar/calendar_display_event.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:rxdart/rxdart.dart';

enum CalendarSourceLoadState { loading, ready, empty, unauthenticated, failed }

enum CalendarSourceRefreshState { idle, refreshing }

final class CalendarSourceFailure {
  const CalendarSourceFailure(this.error, [this.stackTrace]);

  final Object error;
  final StackTrace? stackTrace;
}

final class CalendarSourceSnapshot {
  CalendarSourceSnapshot({
    required this.source,
    required List<CalendarDisplayEvent> events,
    required this.loadState,
    this.refreshState = CalendarSourceRefreshState.idle,
    this.failure,
  }) : events = List.unmodifiable(events);

  factory CalendarSourceSnapshot.loading(CalendarEventSource source) =>
      CalendarSourceSnapshot(
        source: source,
        events: const [],
        loadState: CalendarSourceLoadState.loading,
      );

  factory CalendarSourceSnapshot.failed(
    CalendarEventSource source,
    Object error, [
    StackTrace? stackTrace,
  ]) => CalendarSourceSnapshot(
    source: source,
    events: const [],
    loadState: CalendarSourceLoadState.failed,
    failure: CalendarSourceFailure(error, stackTrace),
  );

  final CalendarEventSource source;
  final List<CalendarDisplayEvent> events;
  final CalendarSourceLoadState loadState;
  final CalendarSourceRefreshState refreshState;
  final CalendarSourceFailure? failure;
}

final class CalendarReadSnapshot {
  CalendarReadSnapshot({
    required List<CalendarDisplayEvent> events,
    required Map<CalendarEventSource, CalendarSourceSnapshot> sources,
  }) : events = List.unmodifiable(events),
       sources = Map.unmodifiable(sources);

  final List<CalendarDisplayEvent> events;
  final Map<CalendarEventSource, CalendarSourceSnapshot> sources;

  CalendarSourceSnapshot get native =>
      sources[CalendarEventSource.nexecute] ??
      CalendarSourceSnapshot.loading(CalendarEventSource.nexecute);
}

abstract interface class CalendarReadSource {
  Stream<CalendarReadSnapshot> watchEvents(CalendarQueryRange range);

  Future<void> refresh(CalendarQueryRange range);
}

abstract interface class ExternalCalendarSource {
  CalendarEventSource get source;

  Stream<CalendarSourceSnapshot> watchEvents(CalendarQueryRange range);

  Future<void> refresh(CalendarQueryRange range);
}

final class CompositeCalendarReadSource implements CalendarReadSource {
  CompositeCalendarReadSource({
    required EventRepository nativeEventRepository,
    Iterable<ExternalCalendarSource> externalSources = const [],
  }) : _nativeEventRepository = nativeEventRepository,
       _externalSources = List.unmodifiable(externalSources) {
    final sourceIds = <String>{CalendarEventSource.nexecute.id};
    for (final externalSource in _externalSources) {
      if (!sourceIds.add(externalSource.source.id)) {
        throw ArgumentError.value(
          externalSource.source.id,
          'externalSources',
          'Calendar source IDs must be unique',
        );
      }
    }
  }

  final EventRepository _nativeEventRepository;
  final List<ExternalCalendarSource> _externalSources;

  @override
  Stream<CalendarReadSnapshot> watchEvents(CalendarQueryRange range) {
    final streams = <Stream<CalendarSourceSnapshot>>[
      _nativeStream(range),
      for (final source in _externalSources) _externalStream(source, range),
    ];
    return Rx.combineLatestList(
      streams,
    ).map((snapshots) => _mergeSnapshots(snapshots, range));
  }

  @override
  Future<void> refresh(CalendarQueryRange range) async {
    await Future.wait([
      for (final source in _externalSources)
        Future<void>(() async {
          try {
            await source.refresh(range);
          } catch (_) {
            // The source stream owns user-visible refresh and failure state.
          }
        }),
    ]);
  }

  Stream<CalendarSourceSnapshot> _nativeStream(CalendarQueryRange range) {
    Stream<DataState<List<Event>>> stream;
    try {
      stream = _nativeEventRepository.watchEvents(range);
    } catch (error, stackTrace) {
      return Stream.value(
        CalendarSourceSnapshot.failed(
          CalendarEventSource.nexecute,
          error,
          stackTrace,
        ),
      );
    }

    return stream
        .map(_mapNativeState)
        .onErrorReturnWith(
          (error, stackTrace) => CalendarSourceSnapshot.failed(
            CalendarEventSource.nexecute,
            error,
            stackTrace,
          ),
        )
        .startWith(
          CalendarSourceSnapshot.loading(CalendarEventSource.nexecute),
        );
  }

  Stream<CalendarSourceSnapshot> _externalStream(
    ExternalCalendarSource source,
    CalendarQueryRange range,
  ) {
    Stream<CalendarSourceSnapshot> stream;
    try {
      stream = source.watchEvents(range);
    } catch (error, stackTrace) {
      return Stream.value(
        CalendarSourceSnapshot.failed(source.source, error, stackTrace),
      );
    }

    return stream
        .map((snapshot) {
          if (snapshot.source != source.source) {
            throw StateError(
              'Calendar source ${source.source.id} emitted '
              '${snapshot.source.id}',
            );
          }
          for (final event in snapshot.events) {
            if (event.source != source.source ||
                event.nativeEvent != null ||
                event.capabilities.canEdit ||
                event.capabilities.canDelete) {
              throw StateError(
                'External calendar source emitted an invalid event',
              );
            }
          }
          return snapshot;
        })
        .onErrorReturnWith(
          (error, stackTrace) =>
              CalendarSourceSnapshot.failed(source.source, error, stackTrace),
        )
        .startWith(CalendarSourceSnapshot.loading(source.source));
  }

  CalendarSourceSnapshot _mapNativeState(DataState<List<Event>> state) {
    final events = [
      for (final event in state.valueOrNull ?? const <Event>[])
        CalendarDisplayEvent.native(event),
    ];
    return switch (state) {
      DataLoading<List<Event>>() => CalendarSourceSnapshot(
        source: CalendarEventSource.nexecute,
        events: events,
        loadState: CalendarSourceLoadState.loading,
      ),
      DataReady<List<Event>>() => CalendarSourceSnapshot(
        source: CalendarEventSource.nexecute,
        events: events,
        loadState: CalendarSourceLoadState.ready,
      ),
      DataEmpty<List<Event>>() => CalendarSourceSnapshot(
        source: CalendarEventSource.nexecute,
        events: events,
        loadState: CalendarSourceLoadState.empty,
      ),
      DataUnauthenticated<List<Event>>() => CalendarSourceSnapshot(
        source: CalendarEventSource.nexecute,
        events: events,
        loadState: CalendarSourceLoadState.unauthenticated,
      ),
      DataFailure<List<Event>>() => CalendarSourceSnapshot(
        source: CalendarEventSource.nexecute,
        events: events,
        loadState: CalendarSourceLoadState.failed,
        failure: CalendarSourceFailure(state.error, state.stackTrace),
      ),
    };
  }

  CalendarReadSnapshot _mergeSnapshots(
    List<CalendarSourceSnapshot> snapshots,
    CalendarQueryRange range,
  ) {
    final bySource = <CalendarEventSource, CalendarSourceSnapshot>{
      for (final snapshot in snapshots) snapshot.source: snapshot,
    };
    final byIdentity = <CalendarEventIdentity, CalendarDisplayEvent>{};
    for (final snapshot in snapshots) {
      for (final event in snapshot.events) {
        if (!_overlaps(event, range)) continue;
        final current = byIdentity[event.identity];
        if (current == null || _prefer(event, current) < 0) {
          byIdentity[event.identity] = event;
        }
      }
    }
    final events =
        byIdentity.values.toList()..sort(compareCalendarDisplayEvents);
    return CalendarReadSnapshot(events: events, sources: bySource);
  }

  bool _overlaps(CalendarDisplayEvent event, CalendarQueryRange range) =>
      event.startTime.isBefore(range.endExclusive) &&
      !event.endTime.isBefore(range.startInclusive);

  int _prefer(CalendarDisplayEvent first, CalendarDisplayEvent second) {
    if (first.isStale != second.isStale) return first.isStale ? 1 : -1;
    return _compareCanonical(first, second);
  }

  int _compareCanonical(
    CalendarDisplayEvent first,
    CalendarDisplayEvent second,
  ) {
    final comparisons = <int>[
      first.startTime.compareTo(second.startTime),
      first.endTime.compareTo(second.endTime),
      _compareBool(first.isAllDay, second.isAllDay),
      first.title.compareTo(second.title),
      first.description.compareTo(second.description),
      first.calendarName.compareTo(second.calendarName),
      (first.sourceTimeZone ?? '').compareTo(second.sourceTimeZone ?? ''),
      (first.externalUrl?.toString() ?? '').compareTo(
        second.externalUrl?.toString() ?? '',
      ),
      (first.calendarColorValue ?? -1).compareTo(
        second.calendarColorValue ?? -1,
      ),
    ];
    return comparisons.firstWhere(
      (comparison) => comparison != 0,
      orElse: () => 0,
    );
  }

  int _compareBool(bool first, bool second) =>
      first == second ? 0 : (first ? 1 : -1);
}
