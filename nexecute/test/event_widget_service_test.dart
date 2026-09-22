import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/domain/calendar/recurring_event_expander.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_recurrence.dart';
import 'package:nexecute/services/event_widget_service.dart';
import 'package:nexecute/themes.dart';

void main() {
  final now = DateTime(2026, 8, 28, 12);

  test('serializes the current week and month for Android widgets', () async {
    final writer = _FakeEventWidgetDataWriter();
    final service = EventWidgetService(writer: writer);
    final events = [
      Event(
        id: 'planning',
        title: 'Planning',
        startTime: DateTime(2026, 8, 24, 9, 5),
        endTime: DateTime(2026, 8, 24, 10),
      ),
      Event(
        id: 'conference',
        title: 'Conference',
        startTime: DateTime(2026, 8, 24, 23),
        endTime: DateTime(2026, 8, 26, 10),
      ),
      Event(
        id: 'holiday',
        title: 'Holiday',
        startTime: DateTime(2026, 8, 26),
        endTime: DateTime(2026, 8, 26, 23, 59),
        isAllDay: true,
      ),
    ];

    await service.updateCurrentCalendar(
      events,
      theme: AppThemePreset.forest,
      now: now,
    );

    expect(writer.values['widget_title'], 'Nexecute');
    expect(writer.values['widget_week_number'], 'W35');
    expect(writer.values['widget_theme'], 'forest');
    expect(writer.values['widget_today_key'], 'fri');
    expect(writer.values['show_weekends'], isTrue);
    expect(writer.values['widget_mon_date'], '24.8');
    expect(writer.values['widget_sun_date'], '30.8');
    expect(writer.values['event_mon_count'], 2);
    expect(writer.values['event_mon_0'], '09:05 Planning');
    expect(writer.values['event_tue_count'], 1);
    expect(writer.values['event_tue_0'], '→ Conference');
    expect(writer.values['event_wed_count'], 2);
    expect(writer.values['event_wed_0'], '→ Conference');
    expect(writer.values['event_wed_1'], 'Holiday');
    expect(writer.values['widget_month_label'], 'August 2026');
    expect(writer.values['widget_month_row_count'], 6);
    expect(writer.values['widget_month_cell_count'], 42);
    expect(writer.values['widget_month_today_date'], '2026-08-28');
    expect(writer.values['widget_month_cell_0_date'], '2026-07-27');
    expect(writer.values['widget_month_cell_0_day'], 27);
    expect(writer.values['widget_month_cell_0_in_month'], isFalse);
    expect(writer.values['widget_month_cell_28_date'], '2026-08-24');
    expect(writer.values['widget_month_cell_28_in_month'], isTrue);
    expect(writer.values['widget_month_cell_28_event_count'], 2);
    expect(writer.values['widget_month_cell_28_event_0'], 'Planning');
    expect(writer.values['widget_month_cell_28_event_1'], 'Conference');
    expect(writer.values['widget_month_cell_41_date'], '2026-09-06');
    expect(writer.values['widget_month_cell_41_in_month'], isFalse);
    expect(writer.values['widget_month_anchor'], '2026-08');
    expect(writer.refreshCount, 1);
  });

  test('serializes an independently navigated widget month', () async {
    final writer = _FakeEventWidgetDataWriter();
    final service = EventWidgetService(writer: writer);
    final event = Event(
      id: 'future',
      title: 'Future planning',
      startTime: DateTime(2036, 1, 15, 9),
      endTime: DateTime(2036, 1, 15, 10),
    );

    await service.updateMonthPage(
      [event],
      anchor: DateTime(2036, 1),
      widgetId: 42,
    );

    expect(writer.values['widget_month_instance_42_anchor'], '2036-01');
    expect(writer.values['widget_month_instance_42_label'], 'January 2036');
    expect(writer.values['widget_month_instance_42_status'], '');
    expect(
      writer.values['widget_month_instance_42_cell_15_event_0'],
      'Future planning',
    );
    expect(writer.refreshCount, 1);
  });

  test('caps month labels and clears stale cell data', () async {
    final writer = _FakeEventWidgetDataWriter();
    final service = EventWidgetService(writer: writer);
    final events = [
      for (var index = 0; index < 3; index++)
        Event(
          id: 'event-$index',
          title: 'Event $index',
          startTime: DateTime(2026, 8, 28, 9 + index),
          endTime: DateTime(2026, 8, 28, 10 + index),
        ),
    ];

    await service.updateCurrentCalendar(
      events,
      theme: AppThemePreset.midnight,
      now: now,
    );

    expect(writer.values['widget_month_cell_32_event_count'], 3);
    expect(writer.values['widget_month_cell_32_event_0'], 'Event 0');
    expect(writer.values['widget_month_cell_32_event_1'], 'Event 1');
    expect(writer.values, isNot(contains('widget_month_cell_32_event_2')));

    await service.updateCurrentCalendar(
      const [],
      theme: AppThemePreset.midnight,
      now: DateTime(2026, 2, 15),
    );

    expect(writer.values['widget_month_row_count'], 5);
    expect(writer.values['widget_month_cell_count'], 35);
    expect(writer.values['widget_month_cell_32_event_count'], 0);
    expect(writer.values['widget_month_cell_32_event_0'], '');
    expect(writer.values['widget_month_cell_32_event_1'], '');
    expect(writer.values['widget_month_cell_35_date'], '');
    expect(writer.values['widget_month_cell_35_day'], 0);
    expect(writer.values['widget_month_cell_35_in_month'], isFalse);
    expect(writer.values['widget_month_cell_35_event_count'], 0);
    expect(writer.values['widget_month_cell_35_event_0'], '');
    expect(writer.values['widget_month_cell_35_event_1'], '');
    expect(writer.refreshCount, 2);
  });

  test('serializes leap February as a five-week grid', () async {
    final writer = _FakeEventWidgetDataWriter();
    final service = EventWidgetService(writer: writer);

    await service.updateCurrentCalendar(
      const [],
      theme: AppThemePreset.midnight,
      now: DateTime(2024, 2, 29, 12),
    );

    expect(writer.values['widget_month_label'], 'February 2024');
    expect(writer.values['widget_month_row_count'], 5);
    expect(writer.values['widget_month_cell_count'], 35);
    expect(writer.values['widget_month_today_date'], '2024-02-29');
    expect(writer.values['widget_month_cell_0_date'], '2024-01-29');
    expect(writer.values['widget_month_cell_0_in_month'], isFalse);
    expect(writer.values['widget_month_cell_31_date'], '2024-02-29');
    expect(writer.values['widget_month_cell_31_day'], 29);
    expect(writer.values['widget_month_cell_31_in_month'], isTrue);
    expect(writer.values['widget_month_cell_31_event_count'], 0);
    expect(writer.values['widget_month_cell_31_event_0'], '');
    expect(writer.values['widget_month_cell_34_date'], '2024-03-03');
    expect(writer.values['widget_month_cell_34_in_month'], isFalse);
  });

  test(
    'serializes multi-day and recurring events across a year boundary',
    () async {
      final writer = _FakeEventWidgetDataWriter();
      final service = EventWidgetService(writer: writer);
      final multiDay = Event(
        id: 'trip',
        title: 'Trip',
        startTime: DateTime(2026, 12, 30),
        endTime: DateTime(2027, 1, 2, 23, 59),
        isAllDay: true,
      );
      final weekly = Event(
        id: 'weekly',
        title: 'Weekly review',
        startTime: DateTime(2026, 12, 3, 9),
        endTime: DateTime(2026, 12, 3, 10),
        recurrence: EventRecurrence.weekly,
      );
      final occurrences = expandRecurringEvent(
        weekly,
        CalendarQueryRange(
          startInclusive: DateTime(2026, 11, 30),
          endExclusive: DateTime(2027, 1, 4),
        ),
      );

      await service.updateCurrentCalendar(
        [multiDay, ...occurrences],
        theme: AppThemePreset.midnight,
        now: DateTime(2026, 12, 31, 12),
      );

      expect(writer.values['widget_month_label'], 'December 2026');
      expect(writer.values['widget_month_row_count'], 5);
      expect(writer.values['widget_month_cell_0_date'], '2026-11-30');
      expect(writer.values['widget_month_cell_0_in_month'], isFalse);
      expect(writer.values['widget_month_cell_30_date'], '2026-12-30');
      expect(writer.values['widget_month_cell_30_event_count'], 1);
      expect(writer.values['widget_month_cell_30_event_0'], 'Trip');
      expect(writer.values['widget_month_cell_31_date'], '2026-12-31');
      expect(writer.values['widget_month_cell_31_event_count'], 2);
      expect(writer.values['widget_month_cell_31_event_0'], 'Trip');
      expect(writer.values['widget_month_cell_31_event_1'], 'Weekly review');
      expect(writer.values['widget_month_cell_32_date'], '2027-01-01');
      expect(writer.values['widget_month_cell_32_in_month'], isFalse);
      expect(writer.values['widget_month_cell_32_event_count'], 1);
      expect(writer.values['widget_month_cell_32_event_0'], 'Trip');
      expect(writer.values['widget_month_cell_33_event_count'], 1);
      expect(writer.values['widget_month_cell_34_event_count'], 0);
      expect(occurrences.last.isGeneratedOccurrence, isTrue);
    },
  );

  test('writes the Cyberpunk Mega identifier for the Android widget', () async {
    final writer = _FakeEventWidgetDataWriter();
    final service = EventWidgetService(writer: writer);

    await service.updateTheme(AppThemePreset.cyberpunkMega);

    expect(writer.values['widget_theme'], 'cyberpunkMega');
    expect(writer.refreshCount, 1);
  });
}

class _FakeEventWidgetDataWriter implements EventWidgetDataWriter {
  final values = <String, Object>{};
  final _firstRefresh = Completer<void>();
  int refreshCount = 0;

  Future<void> get refreshed => _firstRefresh.future;

  @override
  Future<void> saveBool(String key, bool value) async {
    values[key] = value;
  }

  @override
  Future<void> saveInt(String key, int value) async {
    values[key] = value;
  }

  @override
  Future<void> saveString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> refresh() async {
    refreshCount++;
    if (!_firstRefresh.isCompleted) _firstRefresh.complete();
  }
}
