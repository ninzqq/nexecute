import 'package:home_widget/home_widget.dart';
import 'package:nexecute/domain/calendar/calendar_month.dart';
import 'package:nexecute/domain/calendar/gregorian_month_calculator.dart';
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
  Future<void> updateCurrentCalendar(
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
  Future<void> updateCurrentCalendar(
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
  static const androidWeekWidgetName = 'CalendarWidgetProvider';
  static const androidMonthWidgetName = 'CalendarMonthWidgetProvider';

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
  Future<void> refresh() async {
    await Future.wait([
      HomeWidget.updateWidget(
        name: androidWeekWidgetName,
        androidName: androidWeekWidgetName,
      ),
      HomeWidget.updateWidget(
        name: androidMonthWidgetName,
        androidName: androidMonthWidgetName,
      ),
    ]);
  }
}

class EventWidgetService implements EventWidgetUpdater {
  EventWidgetService({EventWidgetDataWriter? writer})
    : _writer = writer ?? HomeWidgetEventDataWriter();

  static const _dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthLabels = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const monthCellCapacity = 42;
  static const monthEventLabelCapacity = 2;

  final EventWidgetDataWriter _writer;
  final IsoWeekCalculator _weekCalculator = IsoWeekCalculator();
  final GregorianMonthCalculator _monthCalculator = GregorianMonthCalculator();

  @override
  Future<void> updateCurrentCalendar(
    List<Event> events, {
    required AppThemePreset theme,
    DateTime? now,
  }) async {
    final anchor = now ?? DateTime.now();
    final week = _weekCalculator.fromDate(anchor);
    final month = _monthCalculator.fromDate(anchor);
    final today = DateTime(anchor.year, anchor.month, anchor.day);

    await _writer.saveString('widget_title', 'Nexecute');
    await _writer.saveString('widget_week_number', 'W${week.weekNumber}');
    await _writer.saveString('widget_theme', theme.name);
    await _writer.saveString('widget_status', '');
    await _writer.saveString('widget_empty_text', 'No events this week');
    await _writer.saveString('widget_month_empty_text', 'No events this month');
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

    await _writer.saveString('widget_month_today_date', _isoDate(today));

    await _writeMonthPage(prefix: 'widget_month', month: month, events: events);

    await _writer.refresh();
  }

  Future<void> updateMonthPage(
    List<Event> events, {
    required DateTime anchor,
    required int widgetId,
  }) async {
    final month = _monthCalculator.fromDate(anchor);
    final prefix = 'widget_month_instance_$widgetId';
    await _writer.saveString('${prefix}_status', '');
    await _writeMonthPage(prefix: prefix, month: month, events: events);
    await _writer.refresh();
  }

  Future<void> updateMonthPageStatus({
    required int widgetId,
    required String message,
  }) async {
    await _writer.saveString(
      'widget_month_instance_${widgetId}_status',
      message,
    );
    await _writer.refresh();
  }

  Future<void> _writeMonthPage({
    required String prefix,
    required CalendarMonth month,
    required List<Event> events,
  }) async {
    await _writer.saveString(
      '${prefix}_label',
      '${_monthLabels[month.month - 1]} ${month.year}',
    );
    await _writer.saveString(
      '${prefix}_anchor',
      '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}',
    );
    await _writer.saveInt('${prefix}_row_count', month.weeks.length);
    await _writer.saveInt('${prefix}_cell_count', month.days.length);

    for (var index = 0; index < monthCellCapacity; index++) {
      final key = '${prefix}_cell_$index';
      if (index >= month.days.length) {
        await _writer.saveString('${key}_date', '');
        await _writer.saveInt('${key}_day', 0);
        await _writer.saveBool('${key}_in_month', false);
        await _writer.saveInt('${key}_event_count', 0);
        for (
          var eventIndex = 0;
          eventIndex < monthEventLabelCapacity;
          eventIndex++
        ) {
          await _writer.saveString('${key}_event_$eventIndex', '');
        }
        continue;
      }

      final day = month.days[index].date;
      final dayEvents = eventsForDay(events, day);
      await _writer.saveString('${key}_date', _isoDate(day));
      await _writer.saveInt('${key}_day', day.day);
      await _writer.saveBool('${key}_in_month', month.contains(day));
      await _writer.saveInt('${key}_event_count', dayEvents.length);
      for (
        var eventIndex = 0;
        eventIndex < monthEventLabelCapacity;
        eventIndex++
      ) {
        final label =
            eventIndex < dayEvents.length
                ? _monthEventLabel(dayEvents[eventIndex])
                : '';
        await _writer.saveString('${key}_event_$eventIndex', label);
      }
    }
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

  String _monthEventLabel(Event event) {
    final title = event.title.trim();
    return title.isEmpty ? 'Untitled event' : title;
  }

  String _isoDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
