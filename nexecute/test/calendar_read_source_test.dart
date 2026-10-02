import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/domain/calendar/calendar_display_event.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/repositories/calendar_read_source.dart';

import 'support/fake_event_repository.dart';

void main() {
  final range = CalendarQueryRange(
    startInclusive: DateTime.utc(2026, 8, 1),
    endExclusive: DateTime.utc(2026, 9, 1),
  );

  group('native state mapping', () {
    final event = _nativeEvent('native-1');
    final error = StateError('offline');
    final cases = <
      ({
        String name,
        DataState<List<Event>> state,
        CalendarSourceLoadState loadState,
        bool hasEvent,
        Object? error,
      })
    >[
      (
        name: 'loading',
        state: const DataLoading<List<Event>>(),
        loadState: CalendarSourceLoadState.loading,
        hasEvent: false,
        error: null,
      ),
      (
        name: 'ready',
        state: DataReady([event]),
        loadState: CalendarSourceLoadState.ready,
        hasEvent: true,
        error: null,
      ),
      (
        name: 'empty',
        state: DataEmpty([event]),
        loadState: CalendarSourceLoadState.empty,
        hasEvent: true,
        error: null,
      ),
      (
        name: 'unauthenticated',
        state: const DataUnauthenticated<List<Event>>(),
        loadState: CalendarSourceLoadState.unauthenticated,
        hasEvent: false,
        error: null,
      ),
      (
        name: 'failure',
        state: DataFailure<List<Event>>(error),
        loadState: CalendarSourceLoadState.failed,
        hasEvent: false,
        error: error,
      ),
    ];

    for (final testCase in cases) {
      test('maps ${testCase.name}', () async {
        final source = CompositeCalendarReadSource(
          nativeEventRepository: FakeEventRepository(state: testCase.state),
        );

        final snapshot = await source.watchEvents(range).last;

        expect(snapshot.native.loadState, testCase.loadState);
        expect(snapshot.native.events, hasLength(testCase.hasEvent ? 1 : 0));
        expect(snapshot.events, hasLength(testCase.hasEvent ? 1 : 0));
        if (testCase.error case final expectedError?) {
          expect(snapshot.native.failure?.error, same(expectedError));
        } else {
          expect(snapshot.native.failure, isNull);
        }
      });
    }
  });

  test('merges sources in deterministic calendar order', () async {
    const externalSource = CalendarEventSource(
      'external',
      displayName: 'External',
    );
    final native = _nativeEvent(
      'native',
      title: 'Zulu',
      start: DateTime.utc(2026, 8, 10, 10),
      end: DateTime.utc(2026, 8, 10, 11),
    );
    final external = _FakeExternalCalendarSource(
      source: externalSource,
      snapshots: Stream.value(
        CalendarSourceSnapshot(
          source: externalSource,
          loadState: CalendarSourceLoadState.ready,
          events: [
            _externalEvent(
              source: externalSource,
              id: 'later-end',
              title: 'Alpha',
              start: DateTime.utc(2026, 8, 10, 10),
              end: DateTime.utc(2026, 8, 10, 12),
            ),
            _externalEvent(
              source: externalSource,
              id: 'early',
              title: 'Early',
              start: DateTime.utc(2026, 8, 10, 8),
              end: DateTime.utc(2026, 8, 10, 9),
            ),
            _externalEvent(
              source: externalSource,
              id: 'all-day',
              title: 'All day',
              start: DateTime.utc(2026, 8, 10, 10),
              end: DateTime.utc(2026, 8, 10, 13),
              isAllDay: true,
            ),
            _externalEvent(
              source: externalSource,
              id: 'same-time',
              title: 'Alpha',
              start: DateTime.utc(2026, 8, 10, 10),
              end: DateTime.utc(2026, 8, 10, 11),
            ),
          ],
        ),
      ),
    );
    final source = CompositeCalendarReadSource(
      nativeEventRepository: FakeEventRepository(events: [native]),
      externalSources: [external],
    );

    final snapshot = await source.watchEvents(range).last;

    expect(snapshot.events.map((event) => event.identity.sourceScopedId), [
      'early',
      'all-day',
      'native',
      'same-time',
      'later-end',
    ]);
  });

  test('prefers fresh content for a duplicate identity', () async {
    const externalSource = CalendarEventSource(
      'external',
      displayName: 'External',
    );
    final stale = _externalEvent(
      source: externalSource,
      id: 'duplicate',
      title: 'Stale title',
      isStale: true,
    );
    final fresh = _externalEvent(
      source: externalSource,
      id: 'duplicate',
      title: 'Fresh title',
    );
    final source = CompositeCalendarReadSource(
      nativeEventRepository: FakeEventRepository(),
      externalSources: [
        _FakeExternalCalendarSource(
          source: externalSource,
          snapshots: Stream.value(
            CalendarSourceSnapshot(
              source: externalSource,
              events: [stale, fresh],
              loadState: CalendarSourceLoadState.ready,
            ),
          ),
        ),
      ],
    );

    final snapshot = await source.watchEvents(range).last;

    expect(snapshot.events, hasLength(1));
    expect(snapshot.events.single, same(fresh));
  });

  test('retains identical content with different identities', () async {
    const externalSource = CalendarEventSource(
      'external',
      displayName: 'External',
    );
    final first = _externalEvent(source: externalSource, id: 'first');
    final second = _externalEvent(source: externalSource, id: 'second');
    final source = CompositeCalendarReadSource(
      nativeEventRepository: FakeEventRepository(),
      externalSources: [
        _FakeExternalCalendarSource(
          source: externalSource,
          snapshots: Stream.value(
            CalendarSourceSnapshot(
              source: externalSource,
              events: [first, second],
              loadState: CalendarSourceLoadState.ready,
            ),
          ),
        ),
      ],
    );

    final snapshot = await source.watchEvents(range).last;

    expect(snapshot.events, hasLength(2));
    expect(snapshot.events, containsAll([first, second]));
  });

  test('filters merged events to the requested range', () async {
    const externalSource = CalendarEventSource(
      'external',
      displayName: 'External',
    );
    final source = CompositeCalendarReadSource(
      nativeEventRepository: FakeEventRepository(),
      externalSources: [
        _FakeExternalCalendarSource(
          source: externalSource,
          snapshots: Stream.value(
            CalendarSourceSnapshot(
              source: externalSource,
              events: [
                _externalEvent(
                  source: externalSource,
                  id: 'overlaps-start',
                  start: DateTime.utc(2026, 7, 31),
                  end: range.startInclusive,
                ),
                _externalEvent(source: externalSource, id: 'inside'),
                _externalEvent(
                  source: externalSource,
                  id: 'at-end',
                  start: range.endExclusive,
                  end: range.endExclusive.add(const Duration(hours: 1)),
                ),
                _externalEvent(
                  source: externalSource,
                  id: 'before',
                  start: DateTime.utc(2026, 7, 30),
                  end: DateTime.utc(2026, 7, 31),
                ),
              ],
              loadState: CalendarSourceLoadState.ready,
            ),
          ),
        ),
      ],
    );

    final snapshot = await source.watchEvents(range).last;

    expect(snapshot.events.map((event) => event.identity.sourceScopedId), [
      'overlaps-start',
      'inside',
    ]);
  });

  test('external stream failure leaves native events visible', () async {
    const externalSource = CalendarEventSource(
      'external',
      displayName: 'External',
    );
    final error = StateError('external unavailable');
    final source = CompositeCalendarReadSource(
      nativeEventRepository: FakeEventRepository(
        events: [_nativeEvent('native')],
      ),
      externalSources: [
        _FakeExternalCalendarSource(
          source: externalSource,
          snapshots: Stream.error(error),
        ),
      ],
    );

    final snapshot = await source.watchEvents(range).last;

    expect(snapshot.events.single.identity.sourceScopedId, 'native');
    expect(
      snapshot.sources[externalSource]?.loadState,
      CalendarSourceLoadState.failed,
    );
    expect(snapshot.sources[externalSource]?.failure?.error, same(error));
    expect(snapshot.native.loadState, CalendarSourceLoadState.ready);
  });

  test(
    'rejects native mutation targets emitted by an external source',
    () async {
      const externalSource = CalendarEventSource(
        'external',
        displayName: 'External',
      );
      final source = CompositeCalendarReadSource(
        nativeEventRepository: FakeEventRepository(
          events: [_nativeEvent('native')],
        ),
        externalSources: [
          _FakeExternalCalendarSource(
            source: externalSource,
            snapshots: Stream.value(
              CalendarSourceSnapshot(
                source: externalSource,
                events: [CalendarDisplayEvent.native(_nativeEvent('forged'))],
                loadState: CalendarSourceLoadState.ready,
              ),
            ),
          ),
        ],
      );

      final snapshot = await source.watchEvents(range).last;

      expect(snapshot.events.map((event) => event.identity.sourceScopedId), [
        'native',
      ]);
      expect(
        snapshot.sources[externalSource]?.loadState,
        CalendarSourceLoadState.failed,
      );
      expect(
        snapshot.sources[externalSource]?.failure?.error,
        isA<StateError>(),
      );
    },
  );

  test('refresh isolates failures and still refreshes every source', () async {
    const failingSource = CalendarEventSource(
      'failing',
      displayName: 'Failing',
    );
    const healthySource = CalendarEventSource(
      'healthy',
      displayName: 'Healthy',
    );
    final failing = _FakeExternalCalendarSource(
      source: failingSource,
      snapshots: const Stream.empty(),
      refreshError: StateError('refresh failed'),
    );
    final healthy = _FakeExternalCalendarSource(
      source: healthySource,
      snapshots: const Stream.empty(),
    );
    final source = CompositeCalendarReadSource(
      nativeEventRepository: FakeEventRepository(),
      externalSources: [failing, healthy],
    );

    await expectLater(source.refresh(range), completes);

    expect(failing.refreshedRanges, [range]);
    expect(healthy.refreshedRanges, [range]);
  });
}

Event _nativeEvent(
  String id, {
  String title = 'Event',
  DateTime? start,
  DateTime? end,
}) {
  final startTime = start ?? DateTime.utc(2026, 8, 10, 9);
  return Event(
    id: id,
    title: title,
    startTime: startTime,
    endTime: end ?? startTime.add(const Duration(hours: 1)),
  );
}

CalendarDisplayEvent _externalEvent({
  required CalendarEventSource source,
  required String id,
  String title = 'Event',
  DateTime? start,
  DateTime? end,
  bool isAllDay = false,
  bool isStale = false,
}) {
  final startTime = start ?? DateTime.utc(2026, 8, 10, 9);
  return CalendarDisplayEvent(
    identity: CalendarEventIdentity(source: source, sourceScopedId: id),
    title: title,
    startTime: startTime,
    endTime: end ?? startTime.add(const Duration(hours: 1)),
    isAllDay: isAllDay,
    calendarName: source.displayName,
    capabilities: CalendarEventCapabilities.readOnly,
    isStale: isStale,
  );
}

final class _FakeExternalCalendarSource implements ExternalCalendarSource {
  _FakeExternalCalendarSource({
    required this.source,
    required this.snapshots,
    this.refreshError,
  });

  @override
  final CalendarEventSource source;
  final Stream<CalendarSourceSnapshot> snapshots;
  final Object? refreshError;
  final List<CalendarQueryRange> refreshedRanges = [];

  @override
  Stream<CalendarSourceSnapshot> watchEvents(CalendarQueryRange range) =>
      snapshots;

  @override
  Future<void> refresh(CalendarQueryRange range) async {
    refreshedRanges.add(range);
    if (refreshError case final error?) throw error;
  }
}
