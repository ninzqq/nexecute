import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/domain/calendar/calendar_day.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/themes.dart';
import 'package:nexecute/ui/calendar/day_column.dart';

void main() {
  testWidgets('selects a date by tapping the body of its week column', (
    tester,
  ) async {
    final date = DateTime(2026, 8, 25);
    var selectionCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemes.forPreset(AppThemePreset.midnight),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 120,
              child: DayColumn(
                day: CalendarDay(date: date),
                events: const [],
                isSelected: false,
                onSelected: () => selectionCount++,
                onEventSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final column = find.byType(DayColumn);
    final bodyPosition = tester.getTopLeft(column) + const Offset(60, 240);
    await tester.tapAt(bodyPosition);
    await tester.pump();

    expect(selectionCount, 1);
  });

  testWidgets('event cards keep their own tap action', (tester) async {
    final date = DateTime(2026, 8, 25);
    final event = Event(
      id: 'event-1',
      title: 'Planning',
      startTime: DateTime(2026, 8, 25, 9),
      endTime: DateTime(2026, 8, 25, 10),
    );
    var daySelections = 0;
    Event? selectedEvent;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemes.forPreset(AppThemePreset.midnight),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 120,
              child: DayColumn(
                day: CalendarDay(date: date),
                events: [event],
                isSelected: false,
                onSelected: () => daySelections++,
                onEventSelected: (value) => selectedEvent = value,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Planning'));
    await tester.pump();

    expect(selectedEvent, same(event));
    expect(daySelections, 0);
  });
}
