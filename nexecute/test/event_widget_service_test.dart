import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/services/event_widget_service.dart';
import 'package:nexecute/themes.dart';

void main() {
  final now = DateTime(2026, 8, 28, 12);

  test('serializes the current week for the Android widget', () async {
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

    await service.updateCurrentWeek(
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
    expect(writer.refreshCount, 1);
  });

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
