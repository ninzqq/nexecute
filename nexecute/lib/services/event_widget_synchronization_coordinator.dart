import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/domain/calendar/gregorian_month_calculator.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/services/event_widget_service.dart';
import 'package:nexecute/themes.dart';

/// Owns the single event subscription used to keep launcher widgets current.
///
/// The subscription is intentionally independent of Calendar's visible range.
/// Its current-month grid contains every day needed by the month widget and the
/// current week needed by the existing week widget.
final class EventWidgetSynchronizationCoordinator with WidgetsBindingObserver {
  EventWidgetSynchronizationCoordinator({
    required EventRepository eventRepository,
    required EventWidgetUpdater widgetUpdater,
    required AppThemePreset Function() themePreset,
    DateTime Function()? now,
    Timer Function(Duration, void Function())? timerFactory,
  }) : _eventRepository = eventRepository,
       _widgetUpdater = widgetUpdater,
       _themePreset = themePreset,
       _now = now ?? DateTime.now,
       _timerFactory = timerFactory ?? Timer.new;

  final EventRepository _eventRepository;
  final EventWidgetUpdater _widgetUpdater;
  final AppThemePreset Function() _themePreset;
  final DateTime Function() _now;
  final Timer Function(Duration, void Function()) _timerFactory;
  final GregorianMonthCalculator _monthCalculator = GregorianMonthCalculator();

  StreamSubscription<DataState<List<Event>>>? _subscription;
  Timer? _dayChangeTimer;
  CalendarQueryRange? _activeRange;
  DataState<List<Event>>? _latestState;
  Future<void> _pendingRefresh = Future.value();
  Future<void> _pendingUpdate = Future.value();
  var _subscriptionGeneration = 0;
  var _started = false;
  var _disposed = false;

  bool get isStarted => _started && !_disposed;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);

    _listenToCurrentMonth();
    _scheduleDayChange();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshForCurrentDate());
    }
  }

  Future<void> refreshForCurrentDate() {
    _pendingRefresh = _pendingRefresh.then((_) async {
      try {
        await _refreshForCurrentDate();
      } catch (_) {
        _enqueue(() => _widgetUpdater.updateStatus('Could not refresh events'));
      }
    });
    return _pendingRefresh;
  }

  Future<void> _refreshForCurrentDate() async {
    if (!_started || _disposed) return;

    final anchor = _now();
    final range = _rangeFor(anchor);
    if (_activeRange != range) {
      _subscriptionGeneration++;
      final previousSubscription = _subscription;
      _subscription = null;
      _activeRange = null;
      _latestState = null;
      await previousSubscription?.cancel();
      if (_disposed) return;
      _listen(range);
    } else {
      final state = _latestState;
      if (state != null) _synchronize(state, anchor: anchor);
      if (_subscription == null) _listen(range);
    }

    _scheduleDayChange();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _dayChangeTimer?.cancel();
    _dayChangeTimer = null;
    _subscriptionGeneration++;
    final subscription = _subscription;
    _subscription = null;
    _activeRange = null;
    _latestState = null;
    await subscription?.cancel();
    await _pendingRefresh;
    await _pendingUpdate;
  }

  void _listenToCurrentMonth() {
    final range = _rangeFor(_now());
    _listen(range);
  }

  void _listen(CalendarQueryRange range) {
    final generation = ++_subscriptionGeneration;
    _activeRange = range;
    try {
      _subscription = _eventRepository
          .watchEvents(range)
          .listen(
            (state) {
              if (_disposed || generation != _subscriptionGeneration) return;
              _latestState = state;
              _synchronize(state);
            },
            onError: (Object _, StackTrace __) {
              if (_disposed || generation != _subscriptionGeneration) return;
              _enqueue(
                () => _widgetUpdater.updateStatus('Could not refresh events'),
              );
            },
            onDone: () {
              if (generation == _subscriptionGeneration) {
                _subscription = null;
              }
            },
          );
    } catch (_) {
      _subscription = null;
      _enqueue(() => _widgetUpdater.updateStatus('Could not refresh events'));
    }
  }

  CalendarQueryRange _rangeFor(DateTime anchor) {
    final month = _monthCalculator.fromDate(anchor);
    return monthGridQueryRange(month);
  }

  void _synchronize(DataState<List<Event>> state, {DateTime? anchor}) {
    switch (state) {
      case DataReady<List<Event>>(:final value) ||
          DataEmpty<List<Event>>(:final value):
        _enqueue(
          () => _widgetUpdater.updateCurrentCalendar(
            value,
            theme: _themePreset(),
            now: anchor ?? _now(),
          ),
        );
      case DataUnauthenticated<List<Event>>():
        _enqueue(
          () => _widgetUpdater.updateStatus(
            'Sign in to Nexecute to refresh events',
          ),
        );
      case DataLoading<List<Event>>():
        break;
      case DataFailure<List<Event>>():
        _enqueue(() => _widgetUpdater.updateStatus('Could not refresh events'));
    }
  }

  void _scheduleDayChange() {
    _dayChangeTimer?.cancel();
    if (!_started || _disposed) return;

    final now = _now();
    final nextDay =
        now.isUtc
            ? DateTime.utc(now.year, now.month, now.day + 1)
            : DateTime(now.year, now.month, now.day + 1);
    final delay = nextDay.difference(now) + const Duration(seconds: 1);
    _dayChangeTimer = _timerFactory(delay, () {
      unawaited(refreshForCurrentDate());
    });
  }

  void _enqueue(Future<void> Function() operation) {
    _pendingUpdate = _pendingUpdate.then((_) async {
      try {
        await operation();
      } catch (_) {
        // Widget availability must never interrupt application data streams.
      }
    });
  }
}
