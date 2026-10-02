import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:nexecute/domain/calendar/calendar_display_event.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/domain/calendar/google_calendar_event_url.dart';
import 'package:nexecute/repositories/calendar_read_source.dart';
import 'package:nexecute/repositories/google_calendar_local_store.dart';
import 'package:nexecute/services/google_calendar_api.dart';
import 'package:nexecute/services/google_calendar_authorization.dart';

typedef GoogleCalendarSourceClock = DateTime Function();

enum GoogleCalendarCatalogLoadState { loading, ready, unauthenticated, failed }

enum GoogleCalendarSourceFailureKind {
  authorization,
  calendarList,
  events,
  localStore,
  malformedResponse,
  rateLimited,
  network,
}

final class GoogleCalendarSourceException implements Exception {
  const GoogleCalendarSourceException(this.kind);

  final GoogleCalendarSourceFailureKind kind;

  @override
  String toString() => 'Google Calendar source failed: ${kind.name}';
}

final class GoogleCalendarCatalogState {
  GoogleCalendarCatalogState({
    required List<GoogleCalendarInfo> calendars,
    required Set<String> selectedCalendarIds,
    required this.loadState,
    this.failure,
  }) : calendars = List.unmodifiable(calendars),
       selectedCalendarIds = Set.unmodifiable(selectedCalendarIds);

  factory GoogleCalendarCatalogState.loading() => GoogleCalendarCatalogState(
    calendars: const [],
    selectedCalendarIds: const {},
    loadState: GoogleCalendarCatalogLoadState.loading,
  );

  factory GoogleCalendarCatalogState.unauthenticated() =>
      GoogleCalendarCatalogState(
        calendars: const [],
        selectedCalendarIds: const {},
        loadState: GoogleCalendarCatalogLoadState.unauthenticated,
      );

  final List<GoogleCalendarInfo> calendars;
  final Set<String> selectedCalendarIds;
  final GoogleCalendarCatalogLoadState loadState;
  final GoogleCalendarSourceException? failure;
}

final class GoogleCalendarSource implements ExternalCalendarSource {
  GoogleCalendarSource({
    required GoogleCalendarAuthorizationService authorization,
    required GoogleCalendarApiGateway api,
    required GoogleCalendarLocalStore store,
    GoogleCalendarSourceClock? clock,
  }) : _authorization = authorization,
       _api = api,
       _store = store,
       _clock = clock ?? DateTime.now {
    _authorizationSubscription = _authorization.states.listen(
      _authorizationChanged,
      onError: (_) => _authorizationChanged(_authorization.state),
    );
    unawaited(_beginAuthorizationState(_authorization.state));
  }

  static const google = CalendarEventSource(
    'google',
    displayName: 'Google Calendar',
  );
  static const _metadataMaxAge = Duration(hours: 24);
  static const _maxCalendarPages = 100;
  static const _maxCalendars = 1000;
  static const maxSelectedCalendars = 24;
  static const _maxEventPagesPerCalendar = 1000;
  static const _maxEventsPerCalendarRange = 100000;

  final GoogleCalendarAuthorizationService _authorization;
  final GoogleCalendarApiGateway _api;
  final GoogleCalendarLocalStore _store;
  final GoogleCalendarSourceClock _clock;
  final _catalogController =
      StreamController<GoogleCalendarCatalogState>.broadcast(sync: true);
  final Set<_GoogleRangeWatcher> _watchers = {};

  late final StreamSubscription<GoogleCalendarAuthorizationState>
  _authorizationSubscription;
  GoogleCalendarCatalogState _catalog = GoogleCalendarCatalogState.loading();
  GoogleCalendarCacheOwner? _loadedOwner;
  GoogleCalendarLocalState? _localState;
  Future<GoogleCalendarLocalState>? _metadataRefreshOperation;
  final Map<
    (GoogleCalendarCacheOwner, int, int, CalendarQueryRange),
    Future<_EventRefreshResult>
  >
  _eventRefreshOperations = {};
  Future<void> _catalogMutationTail = Future<void>.value();
  DateTime? _lastFetchTimestamp;
  int _generation = 0;
  int _catalogRevision = 0;
  bool _disposed = false;

  @override
  CalendarEventSource get source => google;

  GoogleCalendarCatalogState get catalogState => _catalog;

  Stream<GoogleCalendarCatalogState> get catalogStates async* {
    yield _catalog;
    yield* _catalogController.stream;
  }

  @override
  Stream<CalendarSourceSnapshot> watchEvents(CalendarQueryRange range) {
    late final _GoogleRangeWatcher watcher;
    late final StreamController<CalendarSourceSnapshot> controller;
    controller = StreamController<CalendarSourceSnapshot>(
      sync: true,
      onListen: () {
        _watchers.add(watcher);
        unawaited(_runWatcher(watcher));
      },
      onCancel: () {
        watcher.operation += 1;
        _watchers.remove(watcher);
      },
    );
    watcher = _GoogleRangeWatcher(range, controller);
    return controller.stream;
  }

  @override
  Future<void> refresh(CalendarQueryRange range) async {
    final matching = _watchers.where((watcher) => watcher.range == range);
    await Future.wait([
      for (final watcher in matching.toList()) _runWatcher(watcher),
    ]);
  }

  Future<void> refreshCalendars() async {
    final generation = _generation;
    final owner = _connectedOwner();
    if (owner == null) {
      _emitCatalog(GoogleCalendarCatalogState.unauthenticated());
      return;
    }
    try {
      final local = await _load(owner, generation);
      _check(owner, generation);
      await _refreshMetadata(owner, generation, local);
      _check(owner, generation);
      await _refreshAllWatchers();
    } on _CancelledOperation {
      return;
    } catch (error) {
      if (_isCurrent(owner, generation)) {
        _emitCatalogFailure(_sanitizeFailure(error, events: false).kind);
      }
    }
  }

  Future<void> setSelectedCalendarIds(Set<String> calendarIds) async {
    if (calendarIds.length > maxSelectedCalendars) {
      throw ArgumentError.value(
        calendarIds,
        'calendarIds',
        'At most $maxSelectedCalendars calendars may be selected.',
      );
    }
    final catalogRevision = ++_catalogRevision;
    final generation = _generation;
    final owner = _connectedOwner();
    if (owner == null) return;
    try {
      final local = await _load(owner, generation);
      _check(owner, generation);
      if (catalogRevision != _catalogRevision) return;
      final metadata = local.metadata;
      if (metadata == null) {
        await _refreshMetadata(owner, generation, local);
        _check(owner, generation);
        if (catalogRevision != _catalogRevision) return;
      }
      await _scheduleCatalogMutation(() async {
        _check(owner, generation);
        if (catalogRevision != _catalogRevision) return;
        final current = _localState?.metadata;
        if (current == null) return;
        final available =
            current.calendars.map((calendar) => calendar.id).toSet();
        final selected = calendarIds.intersection(available);
        final removed = current.selectedCalendarIds.difference(selected);
        final replacement = GoogleCalendarSelectionMetadata(
          calendars: current.calendars,
          selectedCalendarIds: selected,
          selectionEstablished: true,
          updatedAt: current.updatedAt,
        );
        final committed = await _store.saveMetadata(
          owner,
          replacement,
          removeCalendarIds: removed,
        );
        _check(owner, generation);
        if (catalogRevision != _catalogRevision) return;
        _localState = committed;
        _emitCatalogFromMetadata(replacement);
      });
      if (catalogRevision != _catalogRevision) return;
      await _refreshAllWatchers();
    } on _CancelledOperation {
      return;
    } catch (error) {
      if (_isCurrent(owner, generation)) {
        _emitCatalogFailure(_sanitizeFailure(error, events: false).kind);
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation += 1;
    _catalogRevision += 1;
    _metadataRefreshOperation = null;
    await _authorizationSubscription.cancel();
    for (final watcher in _watchers.toList()) {
      watcher.operation += 1;
      await watcher.controller.close();
    }
    _watchers.clear();
    await _catalogController.close();
    _api.close();
  }

  void _authorizationChanged(GoogleCalendarAuthorizationState state) {
    unawaited(_beginAuthorizationState(state));
  }

  Future<void> _beginAuthorizationState(
    GoogleCalendarAuthorizationState state,
  ) async {
    if (_disposed) return;
    _generation += 1;
    _catalogRevision += 1;
    _metadataRefreshOperation = null;
    _loadedOwner = null;
    _localState = null;
    final owner = _authorization.cacheOwner;
    if (owner == null) {
      if (state.status == GoogleCalendarAuthorizationStatus.failed ||
          state.status == GoogleCalendarAuthorizationStatus.expired) {
        _emitCatalogFailure(GoogleCalendarSourceFailureKind.authorization);
        _emitAll(_authorizationFailureSnapshot());
        return;
      }
      if (state.status == GoogleCalendarAuthorizationStatus.checking ||
          state.status == GoogleCalendarAuthorizationStatus.authorizing) {
        _emitCatalog(GoogleCalendarCatalogState.loading());
        _emitAll(CalendarSourceSnapshot.loading(source));
        return;
      }
      _emitCatalog(GoogleCalendarCatalogState.unauthenticated());
      _emitAll(_unauthenticatedSnapshot());
      return;
    }
    if (state.status == GoogleCalendarAuthorizationStatus.failed ||
        state.status == GoogleCalendarAuthorizationStatus.expired) {
      _emitCatalogFailure(GoogleCalendarSourceFailureKind.authorization);
    } else {
      _emitCatalog(GoogleCalendarCatalogState.loading());
    }
    await Future.wait([
      for (final watcher in _watchers.toList()) _runWatcher(watcher),
    ]);
  }

  Future<void> _runWatcher(_GoogleRangeWatcher watcher) async {
    if (_disposed || watcher.controller.isClosed) return;
    final operation = ++watcher.operation;
    final generation = _generation;
    final state = _authorization.state;
    final owner = _authorization.cacheOwner;
    if (owner == null) {
      final snapshot =
          state.status == GoogleCalendarAuthorizationStatus.failed ||
                  state.status == GoogleCalendarAuthorizationStatus.expired
              ? _authorizationFailureSnapshot()
              : state.status == GoogleCalendarAuthorizationStatus.checking ||
                  state.status == GoogleCalendarAuthorizationStatus.authorizing
              ? CalendarSourceSnapshot.loading(source)
              : _unauthenticatedSnapshot();
      _emitWatcher(watcher, operation, snapshot);
      return;
    }

    try {
      final local = await _load(owner, generation);
      _checkWatcher(watcher, operation, owner, generation);
      final unavailable =
          state.status == GoogleCalendarAuthorizationStatus.expired ||
          state.status == GoogleCalendarAuthorizationStatus.failed;
      if (unavailable) {
        _emitCatalogFailure(GoogleCalendarSourceFailureKind.authorization);
        _emitWatcher(
          watcher,
          operation,
          _snapshotFromCache(
            local,
            watcher.range,
            failure: const GoogleCalendarSourceException(
              GoogleCalendarSourceFailureKind.authorization,
            ),
          ),
        );
        return;
      }
      if (state.status != GoogleCalendarAuthorizationStatus.connected) {
        _emitWatcher(
          watcher,
          operation,
          _snapshotFromCache(local, watcher.range, refreshing: false),
        );
        return;
      }

      _emitWatcher(
        watcher,
        operation,
        _snapshotFromCache(local, watcher.range, refreshing: true),
      );
      var current = local;
      final metadata = current.metadata;
      final metadataAge =
          metadata == null ? null : _clock().difference(metadata.updatedAt);
      if (metadata == null ||
          metadataAge!.isNegative ||
          metadataAge >= _metadataMaxAge) {
        current = await _refreshMetadata(owner, generation, current);
        _checkWatcher(watcher, operation, owner, generation);
      } else {
        _emitCatalogFromMetadata(metadata);
      }
      await _refreshEvents(watcher, operation, owner, generation, current);
    } on _CancelledOperation {
      return;
    } catch (error) {
      if (!_watcherIsCurrent(watcher, operation, owner, generation)) return;
      final failure = _sanitizeFailure(error, events: true);
      if (_catalog.loadState == GoogleCalendarCatalogLoadState.loading) {
        _emitCatalogFailure(failure.kind);
      }
      _emitWatcher(
        watcher,
        operation,
        _snapshotFromCache(
          _localState ?? GoogleCalendarLocalState.empty,
          watcher.range,
          failure: failure,
        ),
      );
    }
  }

  Future<GoogleCalendarLocalState> _load(
    GoogleCalendarCacheOwner owner,
    int generation,
  ) async {
    if (_loadedOwner == owner && _localState != null) return _localState!;
    GoogleCalendarLocalState loaded;
    try {
      loaded = await _store.load(owner);
    } on GoogleCalendarLocalStoreException catch (error) {
      if (error.error != GoogleCalendarLocalStoreError.corruptData) rethrow;
      _check(owner, generation);
      await _store.clearForAccount(owner);
      _check(owner, generation);
      loaded = GoogleCalendarLocalState.empty;
    }
    _check(owner, generation);
    _loadedOwner = owner;
    _localState = loaded;
    _includePersistedFetchTimestamps(loaded);
    final metadata = loaded.metadata;
    if (metadata != null) _emitCatalogFromMetadata(metadata);
    return loaded;
  }

  Future<GoogleCalendarLocalState> _refreshMetadata(
    GoogleCalendarCacheOwner owner,
    int generation,
    GoogleCalendarLocalState local,
  ) {
    final active = _metadataRefreshOperation;
    if (active != null) return active;
    late final Future<GoogleCalendarLocalState> operation;
    operation = _performMetadataRefresh(owner, generation, local).whenComplete(
      () {
        if (identical(_metadataRefreshOperation, operation)) {
          _metadataRefreshOperation = null;
        }
      },
    );
    _metadataRefreshOperation = operation;
    return operation;
  }

  Future<GoogleCalendarLocalState> _performMetadataRefresh(
    GoogleCalendarCacheOwner owner,
    int generation,
    GoogleCalendarLocalState local,
  ) async {
    _emitCatalog(
      GoogleCalendarCatalogState(
        calendars: local.metadata?.calendars ?? const [],
        selectedCalendarIds: local.metadata?.selectedCalendarIds ?? const {},
        loadState: GoogleCalendarCatalogLoadState.loading,
      ),
    );
    final calendars = await _listAllCalendars(owner, generation);
    _check(owner, generation);
    return _scheduleCatalogMutation(() async {
      _check(owner, generation);
      final previous = _localState?.metadata ?? local.metadata;
      final available = calendars.map((calendar) => calendar.id).toSet();
      final selected =
          previous?.selectionEstablished == true
              ? previous!.selectedCalendarIds
                  .intersection(available)
                  .take(maxSelectedCalendars)
                  .toSet()
              : {
                for (final calendar in calendars)
                  if (calendar.defaultSelected) calendar.id,
              }.take(maxSelectedCalendars).toSet();
      final metadata = GoogleCalendarSelectionMetadata(
        calendars: calendars,
        selectedCalendarIds: selected,
        selectionEstablished: previous?.selectionEstablished ?? false,
        updatedAt: _clock(),
      );
      final removed = <String>{
        ...?previous?.calendars.map((calendar) => calendar.id),
      }.difference(available);
      final disabled = (previous?.selectedCalendarIds ?? const <String>{})
          .difference(selected);
      final committed = await _store.saveMetadata(
        owner,
        metadata,
        removeCalendarIds: {...removed, ...disabled},
      );
      _check(owner, generation);
      _localState = committed;
      _emitCatalogFromMetadata(metadata);
      return committed;
    });
  }

  Future<List<GoogleCalendarInfo>> _listAllCalendars(
    GoogleCalendarCacheOwner owner,
    int generation,
  ) async {
    final byId = <String, GoogleCalendarInfo>{};
    final tokens = <String>{};
    String? pageToken;
    var pageCount = 0;
    do {
      pageCount += 1;
      if (pageCount > _maxCalendarPages) _throwMalformedResponse();
      final page = await _authorizedCall(
        owner,
        generation,
        (token) => _api.listCalendars(accessToken: token, pageToken: pageToken),
      );
      _check(owner, generation);
      for (final calendar in page.items) {
        byId.putIfAbsent(calendar.id, () => calendar);
        if (byId.length > _maxCalendars) _throwMalformedResponse();
      }
      final next = page.nextPageToken;
      if (next == null || next.isEmpty) break;
      if (!tokens.add(next)) {
        throw const GoogleCalendarApiException(
          GoogleCalendarApiFailureKind.malformedResponse,
        );
      }
      pageToken = next;
    } while (true);
    final result =
        byId.values.toList()..sort((a, b) {
          final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          return byName != 0 ? byName : a.id.compareTo(b.id);
        });
    return result;
  }

  Future<void> _refreshEvents(
    _GoogleRangeWatcher watcher,
    int operation,
    GoogleCalendarCacheOwner owner,
    int generation,
    GoogleCalendarLocalState local,
  ) async {
    final catalogRevision = _catalogRevision;
    final key = (owner, generation, catalogRevision, watcher.range);
    var active = _eventRefreshOperations[key];
    if (active == null) {
      final fetchedAt = _nextFetchTimestamp();
      late final Future<_EventRefreshResult> operationFuture;
      operationFuture = _performEventRefresh(
        owner,
        generation,
        catalogRevision,
        watcher.range,
        local,
        fetchedAt,
      ).whenComplete(() {
        if (identical(_eventRefreshOperations[key], operationFuture)) {
          _eventRefreshOperations.remove(key);
        }
      });
      _eventRefreshOperations[key] = operationFuture;
      active = operationFuture;
    }
    final result = await active;
    _checkWatcher(watcher, operation, owner, generation);
    _emitWatcher(
      watcher,
      operation,
      _snapshotFromCache(
        result.local,
        watcher.range,
        freshCalendarIds: result.successfulCalendarIds,
        failure: result.failure,
      ),
    );
  }

  Future<_EventRefreshResult> _performEventRefresh(
    GoogleCalendarCacheOwner owner,
    int generation,
    int catalogRevision,
    CalendarQueryRange range,
    GoogleCalendarLocalState local,
    DateTime fetchedAt,
  ) async {
    final selected = local.metadata?.selectedCalendarIds ?? const <String>{};
    if (selected.isEmpty) {
      return _EventRefreshResult(local: local, successfulCalendarIds: const {});
    }
    final infoById = {
      for (final calendar in local.metadata?.calendars ?? const [])
        calendar.id: calendar,
    };
    final replacements = <GoogleCalendarCachedRange>[];
    final successful = <String>{};
    final failures = <GoogleCalendarSourceException>[];
    final ordered = selected.toList()..sort();
    for (final calendarId in ordered) {
      _checkCatalog(owner, generation, catalogRevision);
      try {
        final events = await _listAllEvents(
          owner,
          generation,
          calendarId,
          range,
          infoById[calendarId],
        );
        _checkCatalog(owner, generation, catalogRevision);
        successful.add(calendarId);
        replacements.add(
          GoogleCalendarCachedRange(
            calendarId: calendarId,
            range: range,
            fetchedAt: fetchedAt,
            events: events,
          ),
        );
      } on _CancelledOperation {
        rethrow;
      } catch (error) {
        failures.add(_sanitizeFailure(error, events: true));
      }
    }
    if (replacements.isNotEmpty) {
      _checkCatalog(owner, generation, catalogRevision);
      final committed = await _store.replaceRanges(owner, replacements);
      _checkCatalog(owner, generation, catalogRevision);
      local = committed;
      _localState = committed;
    }
    return _EventRefreshResult(
      local: local,
      successfulCalendarIds: successful,
      failure: failures.isEmpty ? null : _eventFailure(failures),
    );
  }

  DateTime _nextFetchTimestamp() {
    final now = _clock();
    final previous = _lastFetchTimestamp;
    final next =
        previous != null && !now.isAfter(previous)
            ? previous.add(const Duration(microseconds: 1))
            : now;
    _lastFetchTimestamp = next;
    return next;
  }

  void _includePersistedFetchTimestamps(GoogleCalendarLocalState local) {
    for (final range in local.ranges) {
      final previous = _lastFetchTimestamp;
      if (previous == null || range.fetchedAt.isAfter(previous)) {
        _lastFetchTimestamp = range.fetchedAt;
      }
    }
  }

  Future<List<GoogleCalendarCachedEvent>> _listAllEvents(
    GoogleCalendarCacheOwner owner,
    int generation,
    String calendarId,
    CalendarQueryRange range,
    GoogleCalendarInfo? calendar,
  ) async {
    final byIdentity = <String, GoogleCalendarCachedEvent>{};
    final tokens = <String>{};
    String? pageToken;
    var pageCount = 0;
    do {
      pageCount += 1;
      if (pageCount > _maxEventPagesPerCalendar) _throwMalformedResponse();
      final page = await _authorizedCall(
        owner,
        generation,
        (token) => _api.listEvents(
          accessToken: token,
          calendarId: calendarId,
          range: range,
          pageToken: pageToken,
        ),
      );
      _check(owner, generation);
      for (final event in page.items) {
        final id = _sourceScopedId(
          owner.googleAccountId,
          calendarId,
          event.eventId,
          event.occurrenceKey,
        );
        byIdentity.putIfAbsent(
          id,
          () => GoogleCalendarCachedEvent(
            sourceScopedId: id,
            calendarId: calendarId,
            title: event.title,
            description: event.description,
            startTime: event.startTime,
            endTime: event.endTime,
            isAllDay: event.isAllDay,
            calendarName: calendar?.name ?? source.displayName,
            calendarColorValue: calendar?.colorValue,
            sourceTimeZone: event.sourceTimeZone ?? calendar?.timeZone,
            externalUrl: safeGoogleCalendarEventUrl(event.externalUrl),
          ),
        );
        if (byIdentity.length > _maxEventsPerCalendarRange) {
          _throwMalformedResponse();
        }
      }
      final next = page.nextPageToken;
      if (next == null || next.isEmpty) break;
      if (!tokens.add(next)) {
        throw const GoogleCalendarApiException(
          GoogleCalendarApiFailureKind.malformedResponse,
        );
      }
      pageToken = next;
    } while (true);
    final result =
        byIdentity.values.toList()..sort((a, b) {
          final start = a.startTime.compareTo(b.startTime);
          if (start != 0) return start;
          return a.sourceScopedId.compareTo(b.sourceScopedId);
        });
    return result;
  }

  Future<T> _authorizedCall<T>(
    GoogleCalendarCacheOwner owner,
    int generation,
    Future<T> Function(String token) request,
  ) async {
    var handle = await _authorization.accessToken();
    _check(owner, generation);
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        final value = await request(handle.value);
        _check(owner, generation);
        return value;
      } on GoogleCalendarApiException catch (error) {
        if (error.kind != GoogleCalendarApiFailureKind.unauthorized) rethrow;
        if (attempt == 2) {
          await _authorization.markAuthorizationExpired(handle);
          _check(owner, generation);
          rethrow;
        }
        handle = await _authorization.refreshAccessTokenAfterUnauthorized(
          handle,
        );
        _check(owner, generation);
      }
    }
    throw const GoogleCalendarSourceException(
      GoogleCalendarSourceFailureKind.authorization,
    );
  }

  CalendarSourceSnapshot _snapshotFromCache(
    GoogleCalendarLocalState local,
    CalendarQueryRange range, {
    Set<String> freshCalendarIds = const {},
    GoogleCalendarSourceException? failure,
    bool refreshing = false,
  }) {
    final selected = local.metadata?.selectedCalendarIds ?? const <String>{};
    final calendars = {
      for (final calendar in local.metadata?.calendars ?? const [])
        calendar.id: calendar,
    };
    final events = <CalendarDisplayEvent>[];
    var hasCompleteCoverage = local.metadata != null;
    for (final calendarId in selected.toList()..sort()) {
      final ranges =
          local.ranges
              .where((cached) => cached.calendarId == calendarId)
              .toList();
      final exact =
          ranges.where((cached) => cached.range == range).toList()
            ..sort((a, b) => b.fetchedAt.compareTo(a.fetchedAt));
      final candidateList =
          ranges
              .where((cached) => _rangesOverlap(cached.range, range))
              .toList();
      if (exact.isEmpty) hasCompleteCoverage = false;
      candidateList.sort((first, second) {
        final fetched = second.fetchedAt.compareTo(first.fetchedAt);
        if (fetched != 0) return fetched;
        return _cacheRangeKey(first).compareTo(_cacheRangeKey(second));
      });
      final newest = <String, (GoogleCalendarCachedEvent, DateTime)>{};
      final newerCoverage = <CalendarQueryRange>[];
      for (final cachedRange in candidateList) {
        for (final event in cachedRange.events) {
          if (!_eventOverlaps(event, range)) continue;
          if (newerCoverage.any(
            (coverage) => _eventOverlapsRange(event, coverage),
          )) {
            continue;
          }
          final prior = newest[event.sourceScopedId];
          if (prior == null || cachedRange.fetchedAt.isAfter(prior.$2)) {
            newest[event.sourceScopedId] = (event, cachedRange.fetchedAt);
          }
        }
        newerCoverage.add(cachedRange.range);
      }
      for (final entry in newest.values) {
        events.add(
          _displayEvent(
            entry.$1,
            isStale: !freshCalendarIds.contains(calendarId),
            calendarTimeZone: calendars[calendarId]?.timeZone,
          ),
        );
      }
    }
    events.sort(compareCalendarDisplayEvents);
    return CalendarSourceSnapshot(
      source: source,
      events: events,
      loadState:
          failure != null
              ? CalendarSourceLoadState.failed
              : events.isEmpty
              ? refreshing && !hasCompleteCoverage
                  ? CalendarSourceLoadState.loading
                  : CalendarSourceLoadState.empty
              : CalendarSourceLoadState.ready,
      refreshState:
          refreshing
              ? CalendarSourceRefreshState.refreshing
              : CalendarSourceRefreshState.idle,
      failure: failure == null ? null : CalendarSourceFailure(failure),
    );
  }

  CalendarDisplayEvent _displayEvent(
    GoogleCalendarCachedEvent event, {
    required bool isStale,
    String? calendarTimeZone,
  }) {
    final externalUrl = safeGoogleCalendarEventUrl(event.externalUrl);
    return CalendarDisplayEvent(
      identity: CalendarEventIdentity(
        source: source,
        sourceScopedId: event.sourceScopedId,
      ),
      title: event.title,
      description: event.description,
      startTime: event.startTime,
      endTime: event.endTime,
      isAllDay: event.isAllDay,
      calendarName: event.calendarName,
      calendarColorValue: event.calendarColorValue,
      sourceTimeZone: event.sourceTimeZone ?? calendarTimeZone,
      externalUrl: externalUrl,
      isStale: isStale,
      capabilities: CalendarEventCapabilities(
        canEdit: false,
        canDelete: false,
        canOpenExternally: externalUrl != null,
      ),
    );
  }

  GoogleCalendarSourceException _sanitizeFailure(
    Object error, {
    required bool events,
  }) {
    if (error is GoogleCalendarSourceException) return error;
    if (error is GoogleCalendarAuthorizationException) {
      return const GoogleCalendarSourceException(
        GoogleCalendarSourceFailureKind.authorization,
      );
    }
    if (error is GoogleCalendarApiException &&
        error.kind == GoogleCalendarApiFailureKind.malformedResponse) {
      return const GoogleCalendarSourceException(
        GoogleCalendarSourceFailureKind.malformedResponse,
      );
    }
    if (error is GoogleCalendarApiException &&
        error.kind == GoogleCalendarApiFailureKind.rateLimited) {
      return const GoogleCalendarSourceException(
        GoogleCalendarSourceFailureKind.rateLimited,
      );
    }
    if (error is GoogleCalendarApiException &&
        error.kind == GoogleCalendarApiFailureKind.network) {
      return const GoogleCalendarSourceException(
        GoogleCalendarSourceFailureKind.network,
      );
    }
    return GoogleCalendarSourceException(
      error is GoogleCalendarApiException
          ? (events
              ? GoogleCalendarSourceFailureKind.events
              : GoogleCalendarSourceFailureKind.calendarList)
          : GoogleCalendarSourceFailureKind.localStore,
    );
  }

  GoogleCalendarSourceException _eventFailure(
    List<GoogleCalendarSourceException> failures,
  ) {
    const priority = [
      GoogleCalendarSourceFailureKind.authorization,
      GoogleCalendarSourceFailureKind.rateLimited,
      GoogleCalendarSourceFailureKind.network,
      GoogleCalendarSourceFailureKind.malformedResponse,
      GoogleCalendarSourceFailureKind.events,
      GoogleCalendarSourceFailureKind.localStore,
    ];
    for (final kind in priority) {
      for (final failure in failures) {
        if (failure.kind == kind) return failure;
      }
    }
    return const GoogleCalendarSourceException(
      GoogleCalendarSourceFailureKind.events,
    );
  }

  void _emitCatalogFromMetadata(GoogleCalendarSelectionMetadata metadata) {
    _emitCatalog(
      GoogleCalendarCatalogState(
        calendars: metadata.calendars,
        selectedCalendarIds: metadata.selectedCalendarIds,
        loadState: GoogleCalendarCatalogLoadState.ready,
      ),
    );
  }

  void _emitCatalogFailure(GoogleCalendarSourceFailureKind kind) {
    _emitCatalog(
      GoogleCalendarCatalogState(
        calendars: _catalog.calendars,
        selectedCalendarIds: _catalog.selectedCalendarIds,
        loadState: GoogleCalendarCatalogLoadState.failed,
        failure: GoogleCalendarSourceException(kind),
      ),
    );
  }

  void _emitCatalog(GoogleCalendarCatalogState state) {
    if (_disposed) return;
    _catalog = state;
    _catalogController.add(state);
  }

  void _emitAll(CalendarSourceSnapshot snapshot) {
    for (final watcher in _watchers.toList()) {
      if (!watcher.controller.isClosed) watcher.controller.add(snapshot);
    }
  }

  void _emitWatcher(
    _GoogleRangeWatcher watcher,
    int operation,
    CalendarSourceSnapshot snapshot,
  ) {
    if (!_disposed &&
        !watcher.controller.isClosed &&
        watcher.operation == operation) {
      watcher.controller.add(snapshot);
    }
  }

  Future<void> _refreshAllWatchers() async {
    await Future.wait([
      for (final watcher in _watchers.toList()) _runWatcher(watcher),
    ]);
  }

  Future<T> _scheduleCatalogMutation<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _catalogMutationTail = _catalogMutationTail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  GoogleCalendarCacheOwner? _connectedOwner() {
    if (_authorization.state.status !=
        GoogleCalendarAuthorizationStatus.connected) {
      return null;
    }
    return _authorization.cacheOwner;
  }

  bool _isCurrent(GoogleCalendarCacheOwner owner, int generation) =>
      !_disposed &&
      generation == _generation &&
      _authorization.cacheOwner == owner;

  bool _watcherIsCurrent(
    _GoogleRangeWatcher watcher,
    int operation,
    GoogleCalendarCacheOwner owner,
    int generation,
  ) =>
      _isCurrent(owner, generation) &&
      !watcher.controller.isClosed &&
      watcher.operation == operation;

  void _check(GoogleCalendarCacheOwner owner, int generation) {
    if (!_isCurrent(owner, generation)) throw const _CancelledOperation();
  }

  void _checkCatalog(
    GoogleCalendarCacheOwner owner,
    int generation,
    int catalogRevision,
  ) {
    _check(owner, generation);
    if (catalogRevision != _catalogRevision) {
      throw const _CancelledOperation();
    }
  }

  void _checkWatcher(
    _GoogleRangeWatcher watcher,
    int operation,
    GoogleCalendarCacheOwner owner,
    int generation,
  ) {
    if (!_watcherIsCurrent(watcher, operation, owner, generation)) {
      throw const _CancelledOperation();
    }
  }

  CalendarSourceSnapshot _unauthenticatedSnapshot() => CalendarSourceSnapshot(
    source: source,
    events: const [],
    loadState: CalendarSourceLoadState.unauthenticated,
  );

  CalendarSourceSnapshot _authorizationFailureSnapshot() =>
      CalendarSourceSnapshot(
        source: source,
        events: const [],
        loadState: CalendarSourceLoadState.failed,
        failure: const CalendarSourceFailure(
          GoogleCalendarSourceException(
            GoogleCalendarSourceFailureKind.authorization,
          ),
        ),
      );
}

final class _GoogleRangeWatcher {
  _GoogleRangeWatcher(this.range, this.controller);

  final CalendarQueryRange range;
  final StreamController<CalendarSourceSnapshot> controller;
  int operation = 0;
}

final class _EventRefreshResult {
  _EventRefreshResult({
    required this.local,
    required Set<String> successfulCalendarIds,
    this.failure,
  }) : successfulCalendarIds = Set.unmodifiable(successfulCalendarIds);

  final GoogleCalendarLocalState local;
  final Set<String> successfulCalendarIds;
  final GoogleCalendarSourceException? failure;
}

final class _CancelledOperation implements Exception {
  const _CancelledOperation();
}

String _sourceScopedId(
  String accountId,
  String calendarId,
  String eventId,
  String occurrenceKey,
) =>
    sha256
        .convert(
          utf8.encode(
            jsonEncode([accountId, calendarId, eventId, occurrenceKey]),
          ),
        )
        .toString();

bool _rangesOverlap(CalendarQueryRange first, CalendarQueryRange second) =>
    first.startInclusive.isBefore(second.endExclusive) &&
    second.startInclusive.isBefore(first.endExclusive);

bool _eventOverlaps(
  GoogleCalendarCachedEvent event,
  CalendarQueryRange range,
) =>
    event.startTime.isBefore(range.endExclusive) &&
    !event.endTime.isBefore(range.startInclusive);

String _cacheRangeKey(GoogleCalendarCachedRange range) =>
    '${range.range.startInclusive.microsecondsSinceEpoch}\u0000'
    '${range.range.endExclusive.microsecondsSinceEpoch}';

bool _eventOverlapsRange(
  GoogleCalendarCachedEvent event,
  CalendarQueryRange range,
) =>
    event.startTime.isBefore(range.endExclusive) &&
    !event.endTime.isBefore(range.startInclusive);

Never _throwMalformedResponse() =>
    throw const GoogleCalendarApiException(
      GoogleCalendarApiFailureKind.malformedResponse,
    );
