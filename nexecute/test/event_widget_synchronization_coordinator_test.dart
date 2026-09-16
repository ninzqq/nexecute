import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/services/event_widget_service.dart';
import 'package:nexecute/services/event_widget_synchronization_coordinator.dart';
import 'package:nexecute/themes.dart';

import 'support/fake_event_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 8, 28, 12);

  test('owns one bounded current-month-grid subscription', () async {
    final events = [
      Event(
        id: 'leading-day',
        title: 'July close',
        startTime: DateTime(2026, 7, 27, 9),
        endTime: DateTime(2026, 7, 27, 10),
      ),
      Event(
        id: 'current-week',
        title: 'Friday review',
        startTime: DateTime(2026, 8, 28, 14),
        endTime: DateTime(2026, 8, 28, 15),
      ),
      Event(
        id: 'trailing-day',
        title: 'September planning',
        startTime: DateTime(2026, 9, 6, 9),
        endTime: DateTime(2026, 9, 6, 10),
      ),
    ];
    final repository = FakeEventRepository(events: events);
    final updater = _RecordingEventWidgetUpdater();
    final coordinator = EventWidgetSynchronizationCoordinator(
      eventRepository: repository,
      widgetUpdater: updater,
      themePreset: () => AppThemePreset.forest,
      now: () => now,
    );

    coordinator.start();
    coordinator.start();
    await updater.firstEventUpdate;

    expect(repository.watchedRanges, hasLength(1));
    expect(
      repository.watchedRanges.single,
      CalendarQueryRange(
        startInclusive: DateTime(2026, 7, 27),
        endExclusive: DateTime(2026, 9, 7),
      ),
    );
    expect(updater.eventUpdates.single, events);
    expect(updater.themes.single, AppThemePreset.forest);
    expect(updater.updateTimes.single, now);

    await coordinator.dispose();
    await updater.close();
  });

  test(
    'maps authentication and repository failures to widget status',
    () async {
      final repository = _ControlledEventRepository();
      final updater = _RecordingEventWidgetUpdater();
      final coordinator = EventWidgetSynchronizationCoordinator(
        eventRepository: repository,
        widgetUpdater: updater,
        themePreset: () => AppThemePreset.midnight,
        now: () => now,
      );
      coordinator.start();

      final signedOut = updater.statusChanges.stream.firstWhere(
        (status) => status.startsWith('Sign in'),
      );
      repository.add(const DataUnauthenticated<List<Event>>());
      expect(await signedOut, 'Sign in to Nexecute to refresh events');

      final failed = updater.statusChanges.stream.firstWhere(
        (status) => status.startsWith('Could not'),
      );
      repository.add(DataFailure<List<Event>>(StateError('offline')));
      expect(await failed, 'Could not refresh events');

      await coordinator.dispose();
      await repository.close();
      await updater.close();
    },
  );

  test('isolates updater failures and continues processing states', () async {
    final repository = _ControlledEventRepository();
    final updater = _RecordingEventWidgetUpdater(throwOnEventUpdate: true);
    final coordinator = EventWidgetSynchronizationCoordinator(
      eventRepository: repository,
      widgetUpdater: updater,
      themePreset: () => AppThemePreset.midnight,
      now: () => now,
    );
    coordinator.start();

    repository.add(const DataReady<List<Event>>([]));
    final status = updater.statusChanges.stream.first;
    repository.add(const DataUnauthenticated<List<Event>>());

    expect(await status, 'Sign in to Nexecute to refresh events');
    expect(repository.hasListener, isTrue);

    await coordinator.dispose();
    expect(repository.hasListener, isFalse);
    await repository.close();
    await updater.close();
  });

  test('resume reuses cached events and the existing month query', () async {
    var clock = DateTime(2026, 8, 28, 12);
    final event = Event(
      id: 'event',
      title: 'Planning',
      startTime: DateTime(2026, 8, 29, 9),
      endTime: DateTime(2026, 8, 29, 10),
    );
    final repository = _ControlledEventRepository();
    final updater = _RecordingEventWidgetUpdater();
    final coordinator = EventWidgetSynchronizationCoordinator(
      eventRepository: repository,
      widgetUpdater: updater,
      themePreset: () => AppThemePreset.midnight,
      now: () => clock,
    );
    coordinator.start();

    final initialUpdate = updater.eventChanges.stream.first;
    repository.add(DataReady<List<Event>>([event]));
    await initialUpdate;

    clock = DateTime(2026, 8, 29, 8);
    final resumedUpdate = updater.eventChanges.stream.first;
    coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await resumedUpdate;

    expect(repository.watchedRanges, hasLength(1));
    expect(updater.eventUpdates, hasLength(2));
    expect(updater.eventUpdates.last, [event]);
    expect(updater.updateTimes.last, clock);

    await coordinator.dispose();
    await repository.close();
    await updater.close();
  });

  test(
    'month rollover replaces the query before updating both periods',
    () async {
      var clock = DateTime(2026, 8, 31, 23, 59);
      final repository = _ControlledEventRepository();
      final updater = _RecordingEventWidgetUpdater();
      final coordinator = EventWidgetSynchronizationCoordinator(
        eventRepository: repository,
        widgetUpdater: updater,
        themePreset: () => AppThemePreset.midnight,
        now: () => clock,
      );
      coordinator.start();

      final augustUpdate = updater.eventChanges.stream.first;
      repository.add(const DataReady<List<Event>>([]));
      await augustUpdate;

      clock = DateTime(2026, 9, 1);
      await Future.wait([
        coordinator.refreshForCurrentDate(),
        coordinator.refreshForCurrentDate(),
      ]);
      expect(repository.watchedRanges, hasLength(2));
      expect(
        repository.watchedRanges.last,
        CalendarQueryRange(
          startInclusive: DateTime(2026, 8, 31),
          endExclusive: DateTime(2026, 10, 5),
        ),
      );

      final septemberEvent = Event(
        id: 'september',
        title: 'September planning',
        startTime: DateTime(2026, 9, 1, 9),
        endTime: DateTime(2026, 9, 1, 10),
      );
      final septemberUpdate = updater.eventChanges.stream.first;
      repository.add(DataReady<List<Event>>([septemberEvent]));
      await septemberUpdate;

      expect(updater.eventUpdates, hasLength(2));
      expect(updater.eventUpdates.last, [septemberEvent]);
      expect(updater.updateTimes.last, clock);

      await coordinator.dispose();
      await repository.close();
      await updater.close();
    },
  );

  test('local midnight refreshes cached data while the app runs', () async {
    var clock = DateTime(2026, 8, 28, 23, 59, 59);
    late Duration scheduledDelay;
    late void Function() runScheduledRefresh;
    final repository = _ControlledEventRepository();
    final updater = _RecordingEventWidgetUpdater();
    final coordinator = EventWidgetSynchronizationCoordinator(
      eventRepository: repository,
      widgetUpdater: updater,
      themePreset: () => AppThemePreset.midnight,
      now: () => clock,
      timerFactory: (delay, callback) {
        scheduledDelay = delay;
        runScheduledRefresh = callback;
        return Timer(const Duration(days: 1), callback);
      },
    );
    coordinator.start();
    expect(scheduledDelay, const Duration(seconds: 2));

    final initialUpdate = updater.eventChanges.stream.first;
    repository.add(const DataReady<List<Event>>([]));
    await initialUpdate;
    expect(updater.eventUpdates, hasLength(1));

    clock = DateTime(2026, 8, 29);
    final midnightUpdate = updater.eventChanges.stream.first;
    runScheduledRefresh();
    await midnightUpdate;

    expect(repository.watchedRanges, hasLength(1));
    expect(updater.eventUpdates, hasLength(2));
    expect(updater.updateTimes.last, clock);

    await coordinator.dispose();
    await repository.close();
    await updater.close();
  });
}

class _ControlledEventRepository extends FakeEventRepository {
  final _states = StreamController<DataState<List<Event>>>.broadcast();

  bool get hasListener => _states.hasListener;

  void add(DataState<List<Event>> state) => _states.add(state);

  Future<void> close() => _states.close();

  @override
  Stream<DataState<List<Event>>> watchEvents(CalendarQueryRange range) {
    watchedRanges.add(range);
    return _states.stream;
  }
}

class _RecordingEventWidgetUpdater implements EventWidgetUpdater {
  _RecordingEventWidgetUpdater({this.throwOnEventUpdate = false});

  final bool throwOnEventUpdate;
  final eventUpdates = <List<Event>>[];
  final themes = <AppThemePreset>[];
  final updateTimes = <DateTime?>[];
  final statusChanges = StreamController<String>.broadcast();
  final eventChanges = StreamController<List<Event>>.broadcast();
  final _firstEventUpdate = Completer<void>();

  Future<void> get firstEventUpdate => _firstEventUpdate.future;

  Future<void> close() async {
    await statusChanges.close();
    await eventChanges.close();
  }

  @override
  Future<void> updateCurrentCalendar(
    List<Event> events, {
    required AppThemePreset theme,
    DateTime? now,
  }) async {
    eventUpdates.add(events);
    eventChanges.add(events);
    themes.add(theme);
    updateTimes.add(now);
    if (!_firstEventUpdate.isCompleted) _firstEventUpdate.complete();
    if (throwOnEventUpdate) throw StateError('Widget unavailable');
  }

  @override
  Future<void> updateStatus(String message) async {
    statusChanges.add(message);
  }

  @override
  Future<void> updateTheme(AppThemePreset theme) async {}
}
