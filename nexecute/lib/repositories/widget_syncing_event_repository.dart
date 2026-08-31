import 'dart:async';

import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/domain/calendar/iso_week_calculator.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/services/event_widget_service.dart';
import 'package:nexecute/themes.dart';

class WidgetSyncingEventRepository implements EventRepository {
  const WidgetSyncingEventRepository({
    required EventRepository delegate,
    required EventWidgetUpdater widgetService,
    required AppThemePreset Function() themePreset,
    DateTime Function()? now,
  }) : _delegate = delegate,
       _widgetService = widgetService,
       _themePreset = themePreset,
       _now = now ?? DateTime.now;

  final EventRepository _delegate;
  final EventWidgetUpdater _widgetService;
  final AppThemePreset Function() _themePreset;
  final DateTime Function() _now;

  @override
  Stream<DataState<List<Event>>> watchEvents(CalendarQueryRange range) {
    return _delegate.watchEvents(range).map((state) {
      _synchronizeWidget(state, range);
      return state;
    });
  }

  @override
  Future<List<Event>> searchEvents(String query, {int limit = 50}) {
    return _delegate.searchEvents(query, limit: limit);
  }

  @override
  Future<Event> addEvent(Event event) => _delegate.addEvent(event);

  @override
  Future<Event> createEvent(CreateEventCommand command) {
    return _delegate.createEvent(command);
  }

  @override
  Future<void> updateEvent(UpdateEventCommand command) {
    return _delegate.updateEvent(command);
  }

  @override
  Future<void> deleteEvent(Event event) => _delegate.deleteEvent(event);

  void _synchronizeWidget(
    DataState<List<Event>> state,
    CalendarQueryRange range,
  ) {
    if (state is DataUnauthenticated<List<Event>>) {
      _runSafely(
        _widgetService.updateStatus('Sign in to Nexecute to refresh events'),
      );
      return;
    }

    if (!_containsCurrentWeek(range)) return;

    switch (state) {
      case DataReady<List<Event>>(:final value) ||
          DataEmpty<List<Event>>(:final value):
        _runSafely(
          _widgetService.updateCurrentWeek(
            value,
            theme: _themePreset(),
            now: _now(),
          ),
        );
      case DataFailure<List<Event>>():
        _runSafely(_widgetService.updateStatus('Could not refresh events'));
      case DataLoading<List<Event>>() || DataUnauthenticated<List<Event>>():
        break;
    }
  }

  bool _containsCurrentWeek(CalendarQueryRange range) {
    final week = IsoWeekCalculator().fromDate(_now());
    final endExclusive = DateTime(
      week.end.year,
      week.end.month,
      week.end.day + 1,
    );
    return !range.startInclusive.isAfter(week.start) &&
        !range.endExclusive.isBefore(endExclusive);
  }

  void _runSafely(Future<void> operation) {
    unawaited(() async {
      try {
        await operation;
      } catch (_) {
        // Widget availability must never interrupt the event stream.
      }
    }());
  }
}
