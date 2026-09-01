import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/domain/calendar/calendar_day.dart';
import 'package:nexecute/domain/calendar/iso_week_calculator.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/themes.dart';
import 'package:nexecute/ui/calendar/day_column.dart';
import 'package:nexecute/ui/calendar/week_view.dart';

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

  testWidgets('event cards fill the available day-column width', (
    tester,
  ) async {
    final date = DateTime(2026, 8, 25);
    final event = Event(
      id: 'event-1',
      title: 'Planning',
      startTime: DateTime(2026, 8, 25, 9),
      endTime: DateTime(2026, 8, 25, 10),
    );

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
                onSelected: () {},
                onEventSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final eventAreaWidth =
        tester
            .getSize(find.byKey(const ValueKey('week-event-area-2026-8-25')))
            .width;
    final eventWidth =
        tester
            .getSize(find.byKey(const ValueKey('week-event-event-1-2026-8-25')))
            .width;

    expect(eventWidth, eventAreaWidth - 4);
  });

  testWidgets('lists every hour and positions events by time and duration', (
    tester,
  ) async {
    final date = DateTime(2026, 8, 25);
    final event = Event(
      id: 'timed-event',
      title: 'Design review',
      startTime: DateTime(2026, 8, 25, 9, 30),
      endTime: DateTime(2026, 8, 25, 11),
    );
    final timeScrollController = ScrollController(
      initialScrollOffset: weekInitialScrollOffset,
    );
    addTearDown(timeScrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemes.forPreset(AppThemePreset.midnight),
        home: Scaffold(
          body: WeekView(
            week: IsoWeekCalculator().fromDate(date),
            events: [event],
            selectedDay: date,
            onDaySelected: (_) {},
            onEventSelected: (_) {},
            timeScrollController: timeScrollController,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('week-hour-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-hour-23')), findsOneWidget);
    expect(find.byKey(const Key('week-time-grid-scroll-view')), findsOneWidget);
    expect(timeScrollController.offset, weekInitialScrollOffset);

    final areaFinder = find.byKey(const ValueKey('week-event-area-2026-8-25'));
    final areaTop = tester.getTopLeft(areaFinder).dy;
    final fittedHourHeight = tester.getSize(areaFinder).height / 24;
    final eventFinder = find.byKey(
      const ValueKey('week-event-timed-event-2026-8-25'),
    );
    final eventTop = tester.getTopLeft(eventFinder).dy;

    expect(
      eventTop - areaTop,
      moreOrLessEquals(9.5 * fittedHourHeight, epsilon: 0.01),
    );
    expect(
      tester.getSize(eventFinder).height,
      moreOrLessEquals(1.5 * fittedHourHeight, epsilon: 0.01),
    );
    expect(fittedHourHeight, weekHourHeight);
    expect(tester.getSize(areaFinder).height, weekTimeGridHeight);
  });

  testWidgets('shows a title for a thirty-minute event', (tester) async {
    final date = DateTime(2026, 8, 25);
    final event = Event(
      id: 'short-meeting',
      title: 'Standup',
      description: 'This stays in event details',
      startTime: DateTime(2026, 8, 25, 9),
      endTime: DateTime(2026, 8, 25, 9, 30),
    );
    final timeScrollController = ScrollController(
      initialScrollOffset: weekInitialScrollOffset,
    );
    addTearDown(timeScrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemes.forPreset(AppThemePreset.midnight),
        home: Scaffold(
          body: WeekView(
            week: IsoWeekCalculator().fromDate(date),
            events: [event],
            selectedDay: date,
            onDaySelected: (_) {},
            onEventSelected: (_) {},
            timeScrollController: timeScrollController,
          ),
        ),
      ),
    );

    expect(find.text('Standup'), findsOneWidget);
    expect(find.text('This stays in event details'), findsNothing);
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('week-event-short-meeting-2026-8-25')),
          )
          .height,
      weekHourHeight / 2,
    );
  });

  testWidgets('scrolls through the day while keeping date headers fixed', (
    tester,
  ) async {
    final date = DateTime(2026, 8, 25);
    final timeScrollController = ScrollController(
      initialScrollOffset: weekInitialScrollOffset,
    );
    addTearDown(timeScrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemes.forPreset(AppThemePreset.midnight),
        home: Scaffold(
          body: WeekView(
            week: IsoWeekCalculator().fromDate(date),
            events: const [],
            selectedDay: date,
            onDaySelected: (_) {},
            onEventSelected: (_) {},
            timeScrollController: timeScrollController,
          ),
        ),
      ),
    );

    final scrollView = find.byKey(const Key('week-time-grid-scroll-view'));
    final selectedHeader = find.text('Tue\n25');
    final headerTop = tester.getTopLeft(selectedHeader).dy;

    await tester.drag(scrollView, const Offset(0, -240));
    await tester.pumpAndSettle();

    expect(timeScrollController.offset, greaterThan(weekInitialScrollOffset));
    expect(tester.getTopLeft(selectedHeader).dy, headerTop);

    await tester.drag(scrollView, const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(timeScrollController.offset, 0);

    await tester.drag(scrollView, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(
      timeScrollController.offset,
      timeScrollController.position.maxScrollExtent,
    );
  });

  testWidgets('places overlapping events in separate lanes', (tester) async {
    final date = DateTime(2026, 8, 25);
    final firstEvent = Event(
      id: 'first',
      title: 'First',
      startTime: DateTime(2026, 8, 25, 9),
      endTime: DateTime(2026, 8, 25, 10),
    );
    final secondEvent = Event(
      id: 'second',
      title: 'Second',
      startTime: DateTime(2026, 8, 25, 9, 30),
      endTime: DateTime(2026, 8, 25, 10, 30),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemes.forPreset(AppThemePreset.midnight),
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: SingleChildScrollView(
              child: DayColumn(
                day: CalendarDay(date: date),
                events: [firstEvent, secondEvent],
                isSelected: false,
                onSelected: () {},
                onEventSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final areaWidth =
        tester
            .getSize(find.byKey(const ValueKey('week-event-area-2026-8-25')))
            .width;
    final firstFinder = find.byKey(
      const ValueKey('week-event-first-2026-8-25'),
    );
    final secondFinder = find.byKey(
      const ValueKey('week-event-second-2026-8-25'),
    );

    expect(
      tester.getSize(firstFinder).width,
      moreOrLessEquals(areaWidth / 2 - 4, epsilon: 0.01),
    );
    expect(
      tester.getTopLeft(firstFinder).dx,
      isNot(tester.getTopLeft(secondFinder).dx),
    );
  });

  testWidgets('very short events do not overflow their time slot', (
    tester,
  ) async {
    final date = DateTime(2026, 8, 25);
    final event = Event(
      id: 'short',
      title: 'Late reminder',
      startTime: DateTime(2026, 8, 25, 23, 55),
      endTime: DateTime(2026, 8, 26),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemes.forPreset(AppThemePreset.midnight),
        home: Scaffold(
          body: SingleChildScrollView(
            child: DayColumn(
              day: CalendarDay(date: date),
              events: [event],
              isSelected: false,
              onSelected: () {},
              onEventSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('week-event-short-2026-8-25')))
          .height,
      lessThan(5),
    );
  });

  testWidgets('selecting a week event also selects its date', (tester) async {
    final eventDate = DateTime(2026, 8, 25);
    final event = Event(
      id: 'event-1',
      title: 'Planning',
      startTime: DateTime(2026, 8, 25, 9),
      endTime: DateTime(2026, 8, 25, 10),
    );
    DateTime? selectedDay;
    Event? selectedEvent;
    final timeScrollController = ScrollController(
      initialScrollOffset: weekInitialScrollOffset,
    );
    addTearDown(timeScrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemes.forPreset(AppThemePreset.midnight),
        home: Scaffold(
          body: WeekView(
            week: IsoWeekCalculator().fromDate(eventDate),
            events: [event],
            selectedDay: DateTime(2026, 8, 24),
            onDaySelected: (value) => selectedDay = value,
            onEventSelected: (value) => selectedEvent = value,
            timeScrollController: timeScrollController,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Planning'));
    await tester.pump();

    expect(selectedDay, eventDate);
    expect(selectedEvent, same(event));
  });
}
