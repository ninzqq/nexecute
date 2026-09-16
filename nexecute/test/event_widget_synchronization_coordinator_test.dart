import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/services/event_widget_service.dart';
import 'package:nexecute/services/event_widget_synchronization_coordinator.dart';
import 'package:nexecute/themes.dart';

import 'support/fake_event_repository.dart';

void main() {
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
}

class _ControlledEventRepository extends FakeEventRepository {
  final _states = StreamController<DataState<List<Event>>>();

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
  final _firstEventUpdate = Completer<void>();

  Future<void> get firstEventUpdate => _firstEventUpdate.future;

  Future<void> close() => statusChanges.close();

  @override
  Future<void> updateCurrentCalendar(
    List<Event> events, {
    required AppThemePreset theme,
    DateTime? now,
  }) async {
    eventUpdates.add(events);
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
