import 'dart:async';

import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/repositories/calendar_read_source.dart';
import 'package:nexecute/repositories/google_calendar_local_store.dart';
import 'package:nexecute/repositories/google_calendar_source.dart';
import 'package:nexecute/services/google_calendar_api.dart';
import 'package:nexecute/services/google_calendar_authorization.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 1, 12);
  final range = CalendarQueryRange(
    startInclusive: DateTime.utc(2026, 10, 1),
    endExclusive: DateTime.utc(2026, 10, 8),
  );
  const owner = GoogleCalendarCacheOwner(
    nexecuteUserId: 'user-private',
    googleAccountId: 'account-private',
  );

  test(
    'paginates, uses defaults, deduplicates, and passes exact bounds',
    () async {
      final auth = _Authorization(owner);
      final store = _Store();
      final api = _Api();
      api.calendarPages.addAll([
        GoogleCalendarPage(
          items: [_calendar('b', selected: false)],
          nextPageToken: 'calendar-next',
        ),
        GoogleCalendarPage(items: [_calendar('a', selected: true)]),
      ]);
      api.eventPages['a'] = [
        GoogleCalendarPage(
          items: [_event('event', 'occurrence')],
          nextPageToken: 'event-next',
        ),
        GoogleCalendarPage(items: [_event('event', 'occurrence')]),
      ];
      final source = GoogleCalendarSource(
        authorization: auth,
        api: api,
        store: store,
        clock: () => now,
      );
      addTearDown(source.dispose);

      final snapshots = <CalendarSourceSnapshot>[];
      final subscription = source.watchEvents(range).listen(snapshots.add);
      addTearDown(subscription.cancel);
      final result = await _waitFor(
        snapshots,
        (value) => value.loadState == CalendarSourceLoadState.ready,
      );

      expect(result.events, hasLength(1));
      expect(result.events.single.isStale, isFalse);
      expect(
        snapshots.any(
          (snapshot) =>
              snapshot.loadState == CalendarSourceLoadState.loading &&
              snapshot.refreshState == CalendarSourceRefreshState.refreshing,
        ),
        isTrue,
      );
      expect(api.calendarTokens, [null, 'calendar-next']);
      expect(api.eventTokens, [null, 'event-next']);
      expect(api.eventRanges, everyElement(range));
      expect(api.eventCalendarIds, everyElement('a'));
      expect(source.catalogState.calendars.map((value) => value.id), [
        'a',
        'b',
      ]);
      expect(source.catalogState.selectedCalendarIds, {'a'});
    },
  );

  test(
    'cache is emitted stale before refresh and mapper stays read-only',
    () async {
      final auth = _Authorization(owner);
      final store = _Store();
      store.states[owner] = GoogleCalendarLocalState(
        metadata: _metadata(now, [_calendar('a')], const {'a'}),
        ranges: [
          _cachedRange(
            range,
            'a',
            now.subtract(const Duration(hours: 1)),
            title: 'cached',
            externalUrl: Uri.parse('http://unsafe.test/private'),
          ),
        ],
      );
      final pending =
          Completer<GoogleCalendarPage<GoogleCalendarRemoteEvent>>();
      final api = _Api()..eventCompleter = pending;
      final source = GoogleCalendarSource(
        authorization: auth,
        api: api,
        store: store,
        clock: () => now,
      );
      addTearDown(source.dispose);

      final snapshots = <CalendarSourceSnapshot>[];
      final subscription = source.watchEvents(range).listen(snapshots.add);
      addTearDown(subscription.cancel);
      final cached = await _waitFor(
        snapshots,
        (value) => value.events.any((event) => event.title == 'cached'),
      );

      expect(cached.refreshState, CalendarSourceRefreshState.refreshing);
      expect(cached.events.single.isStale, isTrue);
      expect(cached.events.single.capabilities.canEdit, isFalse);
      expect(cached.events.single.capabilities.canDelete, isFalse);
      expect(cached.events.single.capabilities.canOpenExternally, isFalse);
      pending.complete(GoogleCalendarPage(items: const []));
    },
  );

  test('concurrent watchers share one exact-range event refresh', () async {
    final auth = _Authorization(owner);
    final store = _Store();
    store.states[owner] = GoogleCalendarLocalState(
      metadata: _metadata(now, [_calendar('a')], const {'a'}),
      ranges: const [],
    );
    final pending = Completer<GoogleCalendarPage<GoogleCalendarRemoteEvent>>();
    final api = _Api()..eventCompleter = pending;
    final source = GoogleCalendarSource(
      authorization: auth,
      api: api,
      store: store,
      clock: () => now,
    );
    addTearDown(source.dispose);
    final first = <CalendarSourceSnapshot>[];
    final second = <CalendarSourceSnapshot>[];
    final firstSubscription = source.watchEvents(range).listen(first.add);
    final secondSubscription = source.watchEvents(range).listen(second.add);
    addTearDown(firstSubscription.cancel);
    addTearDown(secondSubscription.cancel);
    await _waitUntil(() => api.eventCalendarIds.isNotEmpty);

    expect(api.eventCalendarIds, ['a']);
    pending.complete(
      GoogleCalendarPage(items: [_event('event', 'occurrence')]),
    );
    await _waitFor(first, (snapshot) => snapshot.events.isNotEmpty);
    await _waitFor(second, (snapshot) => snapshot.events.isNotEmpty);

    expect(api.eventCalendarIds, ['a']);
  });

  test('default selection is bounded to the atomic cache capacity', () async {
    final auth = _Authorization(owner);
    final store = _Store();
    final api =
        _Api()
          ..calendarPages.add(
            GoogleCalendarPage(
              items: [
                for (var index = 0; index < 25; index++) _calendar('$index'),
              ],
            ),
          );
    final source = GoogleCalendarSource(
      authorization: auth,
      api: api,
      store: store,
      clock: () => now,
    );
    addTearDown(source.dispose);
    final subscription = source.watchEvents(range).listen((_) {});
    addTearDown(subscription.cancel);

    await _waitUntil(
      () =>
          source.catalogState.loadState == GoogleCalendarCatalogLoadState.ready,
    );

    expect(
      source.catalogState.selectedCalendarIds,
      hasLength(GoogleCalendarSource.maxSelectedCalendars),
    );
    await _waitUntil(
      () =>
          api.eventCalendarIds.length ==
          GoogleCalendarSource.maxSelectedCalendars,
    );
  });

  test('rejects explicit selections beyond the cache capacity', () async {
    final source = GoogleCalendarSource(
      authorization: _Authorization(owner),
      api: _Api(),
      store: _Store(),
      clock: () => now,
    );
    addTearDown(source.dispose);

    await expectLater(
      source.setSelectedCalendarIds({
        for (var index = 0; index < 25; index++) '$index',
      }),
      throwsArgumentError,
    );
  });

  test('new refresh sorts after persisted future-skewed coverage', () async {
    final auth = _Authorization(owner);
    final store = _Store();
    final persistedTime = now.add(const Duration(minutes: 2));
    store.states[owner] = GoogleCalendarLocalState(
      metadata: _metadata(now, [_calendar('a')], const {'a'}),
      ranges: [_cachedRange(range, 'a', persistedTime)],
    );
    final source = GoogleCalendarSource(
      authorization: auth,
      api: _Api(),
      store: store,
      clock: () => now,
    );
    addTearDown(source.dispose);
    final snapshots = <CalendarSourceSnapshot>[];
    final subscription = source.watchEvents(range).listen(snapshots.add);
    addTearDown(subscription.cancel);

    await _waitFor(
      snapshots,
      (snapshot) =>
          snapshot.refreshState == CalendarSourceRefreshState.idle &&
          snapshot.events.isEmpty,
    );

    final refreshed = store.states[owner]!.ranges.singleWhere(
      (cached) => cached.calendarId == 'a' && cached.range == range,
    );
    expect(refreshed.fetchedAt.isAfter(persistedTime), isTrue);
  });

  test('older overlapping response cannot shadow a newer response', () async {
    final broadRange = CalendarQueryRange(
      startInclusive: range.startInclusive.subtract(const Duration(days: 1)),
      endExclusive: range.endExclusive.add(const Duration(days: 1)),
    );
    final auth = _Authorization(owner);
    final store = _Store();
    store.states[owner] = GoogleCalendarLocalState(
      metadata: _metadata(now, [_calendar('a')], const {'a'}),
      ranges: const [],
    );
    final broadResponse =
        Completer<GoogleCalendarPage<GoogleCalendarRemoteEvent>>();
    final narrowResponse =
        Completer<GoogleCalendarPage<GoogleCalendarRemoteEvent>>();
    final api =
        _Api()
          ..eventCompletersByRange[broadRange] = broadResponse
          ..eventCompletersByRange[range] = narrowResponse;
    final source = GoogleCalendarSource(
      authorization: auth,
      api: api,
      store: store,
      clock: () => now,
    );
    addTearDown(source.dispose);
    final broadSubscription = source.watchEvents(broadRange).listen((_) {});
    addTearDown(broadSubscription.cancel);
    await _waitUntil(() => api.eventRanges.contains(broadRange));
    final narrowSubscription = source.watchEvents(range).listen((_) {});
    addTearDown(narrowSubscription.cancel);
    await _waitUntil(() => api.eventRanges.contains(range));

    narrowResponse.complete(GoogleCalendarPage(items: const []));
    await _waitUntil(
      () => store.states[owner]!.ranges.any(
        (cached) => cached.range == range && cached.events.isEmpty,
      ),
    );
    broadResponse.complete(
      GoogleCalendarPage(items: [_event('obsolete', 'obsolete-occurrence')]),
    );
    await _waitUntil(
      () => store.states[owner]!.ranges.any(
        (cached) => cached.range == broadRange,
      ),
    );

    final snapshots = <CalendarSourceSnapshot>[];
    final verificationSubscription = source
        .watchEvents(range)
        .listen(snapshots.add);
    addTearDown(verificationSubscription.cancel);
    final cached = await _waitFor(
      snapshots,
      (snapshot) =>
          snapshot.refreshState == CalendarSourceRefreshState.refreshing,
    );

    expect(cached.events, isEmpty);
  });

  test(
    'catalog reports authorization failure without an event watcher',
    () async {
      final auth = _Authorization(owner);
      final source = GoogleCalendarSource(
        authorization: auth,
        api: _Api(),
        store: _Store(),
        clock: () => now,
      );
      addTearDown(source.dispose);
      auth.state = GoogleCalendarAuthorizationState(
        status: GoogleCalendarAuthorizationStatus.expired,
        account: auth.state.account,
      );
      auth.controller.add(auth.state);

      await _waitUntil(
        () =>
            source.catalogState.loadState ==
            GoogleCalendarCatalogLoadState.failed,
      );

      expect(
        source.catalogState.failure?.kind,
        GoogleCalendarSourceFailureKind.authorization,
      );
    },
  );

  test(
    'explicit selection disables new calendars and removes deselected data',
    () async {
      final auth = _Authorization(owner);
      final store = _Store();
      store.states[owner] = GoogleCalendarLocalState(
        metadata: _metadata(
          now,
          [_calendar('a'), _calendar('b')],
          const {'a', 'b'},
        ),
        ranges: [_cachedRange(range, 'a', now), _cachedRange(range, 'b', now)],
      );
      final api = _Api();
      final source = GoogleCalendarSource(
        authorization: auth,
        api: api,
        store: store,
        clock: () => now,
      );
      addTearDown(source.dispose);

      await source.setSelectedCalendarIds(const {'a'});
      api.calendarPages.add(
        GoogleCalendarPage(
          items: [
            _calendar('a'),
            _calendar('b'),
            _calendar('new', selected: true),
          ],
        ),
      );
      await source.refreshCalendars();

      expect(source.catalogState.selectedCalendarIds, {'a'});
      expect(
        store.removed,
        containsAll(<Set<String>>[
          {'b'},
        ]),
      );
      expect(store.states[owner]!.ranges.map((value) => value.calendarId), [
        'a',
      ]);
      expect(
        store.states[owner]!.metadata!.calendars.map((value) => value.id),
        ['a', 'b', 'new'],
      );
    },
  );

  test(
    'partial failure keeps failed cache stale and replaces success exactly',
    () async {
      final auth = _Authorization(owner);
      final store = _Store();
      final overlap = CalendarQueryRange(
        startInclusive: range.startInclusive.subtract(const Duration(days: 1)),
        endExclusive: range.endExclusive.add(const Duration(days: 1)),
      );
      store.states[owner] = GoogleCalendarLocalState(
        metadata: _metadata(
          now,
          [_calendar('a'), _calendar('b')],
          const {'a', 'b'},
        ),
        ranges: [
          _cachedRange(
            range,
            'a',
            now.subtract(const Duration(days: 1)),
            title: 'cancelled',
          ),
          _cachedRange(
            overlap,
            'a',
            now.subtract(const Duration(hours: 1)),
            title: 'obsolete overlap',
          ),
          _cachedRange(range, 'b', now, title: 'failed cache'),
        ],
      );
      final api = _Api();
      api.eventPages['a'] = [GoogleCalendarPage(items: const [])];
      api.eventErrors['b'] = const GoogleCalendarApiException(
        GoogleCalendarApiFailureKind.rateLimited,
      );
      final source = GoogleCalendarSource(
        authorization: auth,
        api: api,
        store: store,
        clock: () => now,
      );
      addTearDown(source.dispose);

      final snapshots = <CalendarSourceSnapshot>[];
      final subscription = source.watchEvents(range).listen(snapshots.add);
      addTearDown(subscription.cancel);
      final result = await _waitFor(
        snapshots,
        (value) =>
            value.loadState == CalendarSourceLoadState.failed &&
            value.refreshState == CalendarSourceRefreshState.idle,
      );

      expect(result.events.map((event) => event.title), ['failed cache']);
      expect(result.events.single.isStale, isTrue);
      expect(
        (result.failure!.error as GoogleCalendarSourceException).kind,
        GoogleCalendarSourceFailureKind.rateLimited,
      );
      expect(result.failure.toString(), isNot(contains('b')));
      final successfulRanges = store.states[owner]!.ranges.where(
        (cached) => cached.calendarId == 'a',
      );
      expect(successfulRanges, hasLength(2));
      expect(
        successfulRanges.singleWhere((cached) => cached.range == range).events,
        isEmpty,
      );

      final broadSnapshots = <CalendarSourceSnapshot>[];
      final broadSubscription = source
          .watchEvents(overlap)
          .listen(broadSnapshots.add);
      final broadCached = await _waitFor(
        broadSnapshots,
        (snapshot) =>
            snapshot.refreshState == CalendarSourceRefreshState.refreshing,
      );
      expect(
        broadCached.events.any((event) => event.title == 'obsolete overlap'),
        isFalse,
      );
      await broadSubscription.cancel();
    },
  );

  test(
    'recurring moved event keeps stable hashed identity and metadata',
    () async {
      final first = _event('event-private', 'original-private', hour: 9);
      final moved = _event('event-private', 'original-private', hour: 14);
      final firstId = await _fetchSingleId(owner, now, range, first);
      final movedId = await _fetchSingleId(owner, now, range, moved);

      expect(firstId, movedId);
      expect(firstId, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(firstId, isNot(contains('private')));
    },
  );

  test('occurrence identity is scoped to account and calendar', () async {
    final event = _event('event-private', 'occurrence-private');
    final sameTuple = await _fetchSingleId(owner, now, range, event);
    final repeated = await _fetchSingleId(owner, now, range, event);
    final otherAccount = await _fetchSingleId(
      const GoogleCalendarCacheOwner(
        nexecuteUserId: 'user-private',
        googleAccountId: 'other-account-private',
      ),
      now,
      range,
      event,
    );
    final otherCalendar = await _fetchSingleId(
      owner,
      now,
      range,
      event,
      calendarId: 'b',
    );

    expect(repeated, sameTuple);
    expect(otherAccount, isNot(sameTuple));
    expect(otherCalendar, isNot(sameTuple));
  });

  test(
    'preserves gateway-normalized all-day dates and calendar timezone',
    () async {
      final auth = _Authorization(owner);
      final store = _Store();
      store.states[owner] = GoogleCalendarLocalState(
        metadata: _metadata(now, [_calendar('a')], const {'a'}),
        ranges: const [],
      );
      final api = _Api();
      api.eventPages['a'] = [
        GoogleCalendarPage(
          items: [
            GoogleCalendarRemoteEvent(
              eventId: 'all-day',
              occurrenceKey: '2026-10-02',
              title: 'Trip',
              description: '',
              startTime: DateTime(2026, 10, 2),
              endTime: DateTime(2026, 10, 4),
              isAllDay: true,
            ),
          ],
        ),
      ];
      final source = GoogleCalendarSource(
        authorization: auth,
        api: api,
        store: store,
        clock: () => now,
      );
      addTearDown(source.dispose);
      final snapshots = <CalendarSourceSnapshot>[];
      final subscription = source.watchEvents(range).listen(snapshots.add);
      addTearDown(subscription.cancel);

      final result = await _waitFor(
        snapshots,
        (value) => value.events.isNotEmpty && !value.events.single.isStale,
      );
      expect(result.events.single.isAllDay, isTrue);
      expect(result.events.single.startTime, DateTime(2026, 10, 2));
      expect(result.events.single.endTime, DateTime(2026, 10, 4));
      expect(result.events.single.sourceTimeZone, 'Europe/Helsinki');
    },
  );

  test(
    '401 refreshes once and repeated 401 expires exact retry handle',
    () async {
      final auth = _Authorization(owner);
      final store = _Store();
      store.states[owner] = GoogleCalendarLocalState(
        metadata: _metadata(now, [_calendar('a')], const {'a'}),
        ranges: const [],
      );
      final api = _Api()..unauthorizedEventCalls = 1;
      final source = GoogleCalendarSource(
        authorization: auth,
        api: api,
        store: store,
        clock: () => now,
      );
      addTearDown(source.dispose);
      final first = <CalendarSourceSnapshot>[];
      final firstSubscription = source.watchEvents(range).listen(first.add);
      await _waitFor(
        first,
        (value) => value.loadState == CalendarSourceLoadState.empty,
      );
      await firstSubscription.cancel();
      expect(auth.refreshedTokens.map((value) => value.value), ['token-1']);
      expect(auth.expiredTokens, isEmpty);

      api.unauthorizedEventCalls = 3;
      final second = <CalendarSourceSnapshot>[];
      final secondSubscription = source.watchEvents(range).listen(second.add);
      addTearDown(secondSubscription.cancel);
      await _waitUntil(() => auth.expiredTokens.isNotEmpty);
      expect(auth.expiredTokens.single.value, 'token-5');
    },
  );

  test('repeated 401 keeps cached event stale and bounds retries', () async {
    final auth = _Authorization(owner, expireRecoveredToken: true);
    final store = _Store();
    store.states[owner] = GoogleCalendarLocalState(
      metadata: _metadata(now, [_calendar('a')], const {'a'}),
      ranges: [
        _cachedRange(range, 'a', now.subtract(const Duration(hours: 1))),
      ],
    );
    final api = _Api()..unauthorizedEventCalls = 2;
    final source = GoogleCalendarSource(
      authorization: auth,
      api: api,
      store: store,
      clock: () => now,
    );
    addTearDown(source.dispose);
    final snapshots = <CalendarSourceSnapshot>[];
    final subscription = source.watchEvents(range).listen(snapshots.add);
    addTearDown(subscription.cancel);

    final failed = await _waitFor(
      snapshots,
      (snapshot) =>
          snapshot.loadState == CalendarSourceLoadState.failed &&
          snapshot.failure?.error is GoogleCalendarSourceException,
    );

    expect(failed.events.single.title, 'cached');
    expect(failed.events.single.isStale, isTrue);
    expect(
      (failed.failure!.error as GoogleCalendarSourceException).kind,
      GoogleCalendarSourceFailureKind.authorization,
    );
    expect(api.eventCalendarIds, ['a', 'a']);
    expect(auth.refreshedTokens, hasLength(2));
    expect(auth.expiredTokens.single.value, 'token-2');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(api.eventCalendarIds, hasLength(2));
  });

  test('empty selection is authoritative and makes no event request', () async {
    final auth = _Authorization(owner);
    final store = _Store();
    store.states[owner] = GoogleCalendarLocalState(
      metadata: _metadata(now, [_calendar('a')], const {}),
      ranges: [_cachedRange(range, 'a', now)],
    );
    final api = _Api();
    final source = GoogleCalendarSource(
      authorization: auth,
      api: api,
      store: store,
      clock: () => now,
    );
    addTearDown(source.dispose);
    final snapshots = <CalendarSourceSnapshot>[];
    final subscription = source.watchEvents(range).listen(snapshots.add);
    addTearDown(subscription.cancel);

    final result = await _waitFor(
      snapshots,
      (value) =>
          value.loadState == CalendarSourceLoadState.empty &&
          value.refreshState == CalendarSourceRefreshState.idle,
    );
    expect(result.events, isEmpty);
    expect(api.eventCalendarIds, isEmpty);
  });

  test(
    'account transition cancels work before the authorization cleanup',
    () async {
      final auth = _Authorization(owner);
      final store = _Store();
      store.states[owner] = GoogleCalendarLocalState(
        metadata: _metadata(now, [_calendar('a')], const {'a'}),
        ranges: const [],
      );
      store.replaceStarted = Completer<void>();
      store.releaseReplace = Completer<void>();
      final api = _Api();
      api.eventPages['a'] = [
        GoogleCalendarPage(items: [_event('event', 'occurrence')]),
      ];
      final source = GoogleCalendarSource(
        authorization: auth,
        api: api,
        store: store,
        clock: () => now,
      );
      addTearDown(source.dispose);
      final subscription = source.watchEvents(range).listen((_) {});
      addTearDown(subscription.cancel);
      await store.replaceStarted!.future;

      auth.disconnectNow();
      store.releaseReplace!.complete();
      await Future<void>.delayed(Duration.zero);
      await store.clearForAccount(owner);

      expect(store.states[owner], isNull);
    },
  );

  test('corrupt local state is cleared and recovered from the API', () async {
    final auth = _Authorization(owner);
    final store =
        _Store()
          ..loadError = const GoogleCalendarLocalStoreException(
            GoogleCalendarLocalStoreError.corruptData,
            'sanitized',
          );
    final api = _Api();
    api.calendarPages.add(
      GoogleCalendarPage(items: [_calendar('a', selected: true)]),
    );
    api.eventPages['a'] = [
      GoogleCalendarPage(items: [_event('event', 'occurrence')]),
    ];
    final source = GoogleCalendarSource(
      authorization: auth,
      api: api,
      store: store,
      clock: () => now,
    );
    addTearDown(source.dispose);
    final snapshots = <CalendarSourceSnapshot>[];
    final subscription = source.watchEvents(range).listen(snapshots.add);
    addTearDown(subscription.cancel);

    final result = await _waitFor(
      snapshots,
      (snapshot) =>
          snapshot.events.isNotEmpty && !snapshot.events.single.isStale,
    );

    expect(result.events.single.title, 'Remote event');
    expect(store.cleared, contains(owner));
  });
}

GoogleCalendarInfo _calendar(String id, {bool selected = true}) =>
    GoogleCalendarInfo(
      id: id,
      name: 'Calendar $id',
      accessRole: 'reader',
      defaultSelected: selected,
      colorValue: 0xff123456,
      timeZone: 'Europe/Helsinki',
    );

GoogleCalendarRemoteEvent _event(
  String id,
  String occurrence, {
  int hour = 9,
}) => GoogleCalendarRemoteEvent(
  eventId: id,
  occurrenceKey: occurrence,
  title: 'Remote event',
  description: 'Description',
  startTime: DateTime.utc(2026, 10, 2, hour),
  endTime: DateTime.utc(2026, 10, 2, hour + 1),
  isAllDay: false,
  externalUrl: Uri.parse('https://calendar.google.com/event'),
);

GoogleCalendarSelectionMetadata _metadata(
  DateTime now,
  List<GoogleCalendarInfo> calendars,
  Set<String> selected,
) => GoogleCalendarSelectionMetadata(
  calendars: calendars,
  selectedCalendarIds: selected,
  selectionEstablished: true,
  updatedAt: now,
);

GoogleCalendarCachedRange _cachedRange(
  CalendarQueryRange range,
  String calendarId,
  DateTime fetchedAt, {
  String title = 'cached',
  Uri? externalUrl,
}) => GoogleCalendarCachedRange(
  calendarId: calendarId,
  range: range,
  fetchedAt: fetchedAt,
  events: [
    GoogleCalendarCachedEvent(
      sourceScopedId: '$calendarId-$title',
      calendarId: calendarId,
      title: title,
      description: '',
      startTime: DateTime.utc(2026, 10, 2, 9),
      endTime: DateTime.utc(2026, 10, 2, 10),
      isAllDay: false,
      calendarName: 'Calendar $calendarId',
      externalUrl: externalUrl,
    ),
  ],
);

Future<T> _waitFor<T>(List<T> values, bool Function(T value) predicate) async {
  for (var attempt = 0; attempt < 200; attempt += 1) {
    for (final value in values) {
      if (predicate(value)) return value;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw StateError('Timed out waiting for source state');
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 200; attempt += 1) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw StateError('Timed out waiting for condition');
}

Future<String> _fetchSingleId(
  GoogleCalendarCacheOwner owner,
  DateTime now,
  CalendarQueryRange range,
  GoogleCalendarRemoteEvent event, {
  String calendarId = 'a',
}) async {
  final auth = _Authorization(owner);
  final store = _Store();
  store.states[owner] = GoogleCalendarLocalState(
    metadata: _metadata(now, [_calendar(calendarId)], {calendarId}),
    ranges: const [],
  );
  final api = _Api();
  api.eventPages[calendarId] = [
    GoogleCalendarPage(items: [event]),
  ];
  final source = GoogleCalendarSource(
    authorization: auth,
    api: api,
    store: store,
    clock: () => now,
  );
  final snapshots = <CalendarSourceSnapshot>[];
  final subscription = source.watchEvents(range).listen(snapshots.add);
  final result = await _waitFor(
    snapshots,
    (value) => value.events.isNotEmpty && !value.events.single.isStale,
  );
  await subscription.cancel();
  await source.dispose();
  return result.events.single.identity.sourceScopedId;
}

final class _Authorization implements GoogleCalendarAuthorizationService {
  _Authorization(this.cacheOwner, {this.expireRecoveredToken = false});

  final controller =
      StreamController<GoogleCalendarAuthorizationState>.broadcast(sync: true);
  final List<GoogleCalendarAccessToken> refreshedTokens = [];
  final List<GoogleCalendarAccessToken> expiredTokens = [];
  final bool expireRecoveredToken;
  int token = 0;

  @override
  GoogleCalendarCacheOwner? cacheOwner;

  @override
  GoogleCalendarAuthorizationState state =
      const GoogleCalendarAuthorizationState(
        status: GoogleCalendarAuthorizationStatus.connected,
        account: GoogleCalendarAccountIdentity(
          id: 'account-private',
          email: 'private@example.test',
        ),
      );

  @override
  Stream<GoogleCalendarAuthorizationState> get states => controller.stream;

  @override
  Future<GoogleCalendarAccessToken> accessToken() async =>
      GoogleCalendarAccessToken('token-${++token}');

  @override
  Future<GoogleCalendarAccessToken> refreshAccessTokenAfterUnauthorized(
    GoogleCalendarAccessToken rejectedToken,
  ) async {
    refreshedTokens.add(rejectedToken);
    if (expireRecoveredToken && refreshedTokens.length > 1) {
      await markAuthorizationExpired(rejectedToken);
      throw const GoogleCalendarAuthorizationException(
        GoogleCalendarAuthorizationIssue.accessTokenUnavailable,
      );
    }
    return GoogleCalendarAccessToken('token-${++token}');
  }

  @override
  Future<void> markAuthorizationExpired(
    GoogleCalendarAccessToken rejectedToken,
  ) async {
    expiredTokens.add(rejectedToken);
    state = GoogleCalendarAuthorizationState(
      status: GoogleCalendarAuthorizationStatus.expired,
      account: state.account,
    );
    controller.add(state);
  }

  void disconnectNow() {
    cacheOwner = null;
    state = GoogleCalendarAuthorizationState.disconnected;
    controller.add(state);
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async => disconnectNow();

  @override
  Future<void> dispose() => controller.close();
}

final class _Api implements GoogleCalendarApiGateway {
  final List<GoogleCalendarPage<GoogleCalendarInfo>> calendarPages = [];
  final Map<String, List<GoogleCalendarPage<GoogleCalendarRemoteEvent>>>
  eventPages = {};
  final Map<String, Object> eventErrors = {};
  final List<String?> calendarTokens = [];
  final List<String?> eventTokens = [];
  final List<String> eventCalendarIds = [];
  final List<CalendarQueryRange> eventRanges = [];
  Completer<GoogleCalendarPage<GoogleCalendarRemoteEvent>>? eventCompleter;
  final Map<
    CalendarQueryRange,
    Completer<GoogleCalendarPage<GoogleCalendarRemoteEvent>>
  >
  eventCompletersByRange = {};
  int unauthorizedEventCalls = 0;

  @override
  Future<GoogleCalendarPage<GoogleCalendarInfo>> listCalendars({
    required String accessToken,
    String? pageToken,
  }) async {
    calendarTokens.add(pageToken);
    if (calendarPages.isEmpty) return GoogleCalendarPage(items: const []);
    return calendarPages.removeAt(0);
  }

  @override
  Future<GoogleCalendarPage<GoogleCalendarRemoteEvent>> listEvents({
    required String accessToken,
    required String calendarId,
    required CalendarQueryRange range,
    String? pageToken,
  }) async {
    eventTokens.add(pageToken);
    eventCalendarIds.add(calendarId);
    eventRanges.add(range);
    if (unauthorizedEventCalls > 0) {
      unauthorizedEventCalls -= 1;
      throw const GoogleCalendarApiException(
        GoogleCalendarApiFailureKind.unauthorized,
      );
    }
    final error = eventErrors[calendarId];
    if (error != null) throw error;
    final rangeCompleter = eventCompletersByRange[range];
    if (rangeCompleter != null) return rangeCompleter.future;
    final completer = eventCompleter;
    if (completer != null) return completer.future;
    final pages = eventPages[calendarId];
    if (pages == null || pages.isEmpty) {
      return GoogleCalendarPage(items: const []);
    }
    return pages.removeAt(0);
  }

  @override
  void close() {}
}

final class _Store implements GoogleCalendarLocalStore {
  final Map<GoogleCalendarCacheOwner, GoogleCalendarLocalState> states = {};
  final List<Set<String>> removed = [];
  final List<GoogleCalendarCacheOwner> cleared = [];
  Completer<void>? replaceStarted;
  Completer<void>? releaseReplace;
  Object? loadError;

  @override
  Future<GoogleCalendarLocalState> load(GoogleCalendarCacheOwner owner) async {
    final error = loadError;
    loadError = null;
    if (error != null) throw error;
    return states[owner] ?? GoogleCalendarLocalState.empty;
  }

  @override
  Future<GoogleCalendarLocalState> saveMetadata(
    GoogleCalendarCacheOwner owner,
    GoogleCalendarSelectionMetadata metadata, {
    Set<String> removeCalendarIds = const {},
  }) async {
    if (removeCalendarIds.isNotEmpty) {
      removed.add(Set.of(removeCalendarIds));
    }
    final current = states[owner] ?? GoogleCalendarLocalState.empty;
    states[owner] = GoogleCalendarLocalState(
      metadata: metadata,
      ranges: [
        for (final range in current.ranges)
          if (!removeCalendarIds.contains(range.calendarId)) range,
      ],
    );
    return states[owner]!;
  }

  @override
  Future<GoogleCalendarLocalState> replaceRanges(
    GoogleCalendarCacheOwner owner,
    List<GoogleCalendarCachedRange> replacements,
  ) async {
    replaceStarted?.complete();
    await releaseReplace?.future;
    final current = states[owner] ?? GoogleCalendarLocalState.empty;
    final ranges = [...current.ranges];
    for (final replacement in replacements) {
      ranges.removeWhere(
        (value) =>
            value.calendarId == replacement.calendarId &&
            value.range == replacement.range,
      );
      ranges.add(replacement);
    }
    states[owner] = GoogleCalendarLocalState(
      metadata: current.metadata,
      ranges: ranges,
    );
    return states[owner]!;
  }

  @override
  Future<GoogleCalendarLocalState> removeCalendars(
    GoogleCalendarCacheOwner owner,
    Set<String> calendarIds,
  ) async {
    removed.add(Set.of(calendarIds));
    final current = states[owner] ?? GoogleCalendarLocalState.empty;
    final metadata = current.metadata;
    states[owner] = GoogleCalendarLocalState(
      metadata:
          metadata == null
              ? null
              : GoogleCalendarSelectionMetadata(
                calendars:
                    metadata.calendars
                        .where((value) => !calendarIds.contains(value.id))
                        .toList(),
                selectedCalendarIds: metadata.selectedCalendarIds.difference(
                  calendarIds,
                ),
                selectionEstablished: metadata.selectionEstablished,
                updatedAt: metadata.updatedAt,
              ),
      ranges:
          current.ranges
              .where((value) => !calendarIds.contains(value.calendarId))
              .toList(),
    );
    return states[owner]!;
  }

  @override
  Future<void> clearForAccount(GoogleCalendarCacheOwner owner) async {
    cleared.add(owner);
    states.remove(owner);
  }

  @override
  Future<void> dispose() async {}
}
