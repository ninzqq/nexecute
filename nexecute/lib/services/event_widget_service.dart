import 'package:home_widget/home_widget.dart';
import 'package:nexecute/domain/calendar/iso_week_calculator.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/themes.dart';
import 'package:nexecute/ui/calendar/event_date_utils.dart';

abstract interface class EventWidgetDataWriter {
  Future<void> saveString(String key, String value);

  Future<void> saveInt(String key, int value);

  Future<void> saveBool(String key, bool value);

  Future<void> refresh();
}

abstract interface class EventWidgetUpdater {
  Future<void> updateCurrentWeek(
    List<Event> events, {
    required AppThemePreset theme,
    DateTime? now,
  });

  Future<void> updateStatus(String message);

  Future<void> updateTheme(AppThemePreset theme);
}

class NoopEventWidgetUpdater implements EventWidgetUpdater {
  const NoopEventWidgetUpdater();

  @override
  Future<void> updateCurrentWeek(
    List<Event> events, {
    required AppThemePreset theme,
    DateTime? now,
  }) async {}

  @override
  Future<void> updateStatus(String message) async {}

  @override
  Future<void> updateTheme(AppThemePreset theme) async {}
}

class HomeWidgetEventDataWriter implements EventWidgetDataWriter {
  static const androidWidgetName = 'CalendarWidgetProvider';

  @override
  Future<void> saveString(String key, String value) {
    return HomeWidget.saveWidgetData<String>(key, value);
  }

  @override
  Future<void> saveInt(String key, int value) {
    return HomeWidget.saveWidgetData<int>(key, value);
  }

  @override
  Future<void> saveBool(String key, bool value) {
    return HomeWidget.saveWidgetData<bool>(key, value);
  }

  @override
  Future<void> refresh() {
    return HomeWidget.updateWidget(
      name: androidWidgetName,
      androidName: androidWidgetName,
    );
  }
}

class EventWidgetService implements EventWidgetUpdater {
  EventWidgetService({EventWidgetDataWriter? writer})
    : _writer = writer ?? HomeWidgetEventDataWriter();

  static const _dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final EventWidgetDataWriter _writer;
  final IsoWeekCalculator _weekCalculator = IsoWeekCalculator();

  @override
  Future<void> updateCurrentWeek(
    List<Event> events, {
    required AppThemePreset theme,
    DateTime? now,
  }) async {
    final anchor = now ?? DateTime.now();
    final week = _weekCalculator.fromDate(anchor);
    final today = DateTime(anchor.year, anchor.month, anchor.day);

    await _writer.saveString('widget_title', 'Nexecute');
    await _writer.saveString('widget_week_number', 'W${week.weekNumber}');
    await _writer.saveString('widget_theme', theme.name);
    await _writer.saveString('widget_status', '');
    await _writer.saveString('widget_empty_text', 'No events this week');
    await _writer.saveBool('show_weekends', true);

    final todayKey =
        week.days.any((day) => isSameCalendarDay(day.date, today))
            ? _dayKeys[today.weekday - DateTime.monday]
            : '';
    await _writer.saveString('widget_today_key', todayKey);

    for (var index = 0; index < week.days.length; index++) {
      final day = week.days[index].date;
      final dayKey = _dayKeys[index];
      final dayEvents = eventsForDay(events, day);

      await _writer.saveString('widget_${dayKey}_label', _dayLabels[index]);
      await _writer.saveString(
        'widget_${dayKey}_date',
        '${day.day}.${day.month}',
      );
      await _writer.saveInt('event_${dayKey}_count', dayEvents.length);

      for (var eventIndex = 0; eventIndex < dayEvents.length; eventIndex++) {
        await _writer.saveString(
          'event_${dayKey}_$eventIndex',
          _eventLabel(dayEvents[eventIndex], day),
        );
      }
    }

    await _writer.refresh();
  }

  @override
  Future<void> updateStatus(String message) async {
    await _writer.saveString('widget_status', message);
    await _writer.refresh();
  }

  @override
  Future<void> updateTheme(AppThemePreset theme) async {
    await _writer.saveString('widget_theme', theme.name);
    await _writer.refresh();
  }

  String _eventLabel(Event event, DateTime day) {
    final title = event.title.trim().isEmpty ? 'Untitled event' : event.title;
    if (event.isAllDay) return title;
    if (!isSameCalendarDay(event.startTime, day)) return '→ $title';

    final hour = event.startTime.hour.toString().padLeft(2, '0');
    final minute = event.startTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $title';
  }
}
