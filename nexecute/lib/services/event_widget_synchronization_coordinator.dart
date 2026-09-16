import 'dart:async';

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
final class EventWidgetSynchronizationCoordinator {
  EventWidgetSynchronizationCoordinator({
    required EventRepository eventRepository,
    required EventWidgetUpdater widgetUpdater,
    required AppThemePreset Function() themePreset,
    DateTime Function()? now,
  }) : _eventRepository = eventRepository,
       _widgetUpdater = widgetUpdater,
       _themePreset = themePreset,
       _now = now ?? DateTime.now;

  final EventRepository _eventRepository;
  final EventWidgetUpdater _widgetUpdater;
  final AppThemePreset Function() _themePreset;
  final DateTime Function() _now;
  final GregorianMonthCalculator _monthCalculator = GregorianMonthCalculator();

  StreamSubscription<DataState<List<Event>>>? _subscription;
  Future<void> _pendingUpdate = Future.value();

  bool get isStarted => _subscription != null;

  void start() {
    if (_subscription != null) return;

    final month = _monthCalculator.fromDate(_now());
    final range = monthGridQueryRange(month);
    try {
      _subscription = _eventRepository
          .watchEvents(range)
          .listen(
            _synchronize,
            onError: (Object _, StackTrace __) {
              _enqueue(
                () => _widgetUpdater.updateStatus('Could not refresh events'),
              );
            },
          );
    } catch (_) {
      _enqueue(() => _widgetUpdater.updateStatus('Could not refresh events'));
    }
  }

  Future<void> dispose() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    await _pendingUpdate;
  }

  void _synchronize(DataState<List<Event>> state) {
    switch (state) {
      case DataReady<List<Event>>(:final value) ||
          DataEmpty<List<Event>>(:final value):
        _enqueue(
          () => _widgetUpdater.updateCurrentWeek(
            value,
            theme: _themePreset(),
            now: _now(),
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
