import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nexecute/domain/calendar/iso_week_calculator.dart';
import 'package:nexecute/models/selected_day.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/themes.dart';
import 'package:nexecute/ui/calendar/calendar.dart';
import 'package:nexecute/ui/calendar/week_view.dart';
import 'package:provider/provider.dart';

import 'support/fake_event_repository.dart';

void main() {
  testWidgets('calendar pager survives fractional desktop width changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(574.36, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<EventRepository>.value(value: FakeEventRepository()),
          ChangeNotifierProvider(create: (_) => SelectedDay()),
        ],
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: const CalendarPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(574.4, 900);
    await tester.pump();

    expect(tester.takeException(), isNull);

    final originalController =
        tester.widget<PageView>(find.byType(PageView).first).controller!;
    originalController.jumpToPage(20);
    await tester.pumpAndSettle();

    final recenteredController =
        tester.widget<PageView>(find.byType(PageView).first).controller!;
    expect(recenteredController, isNot(same(originalController)));
    expect(recenteredController.page, 120);

    final today = DateTime.now();
    final expectedMonth = DateTime(today.year, today.month - 100);
    expect(
      find.text(DateFormat('MMMM yyyy').format(expectedMonth)),
      findsOneWidget,
    );
  });

  testWidgets('horizontal swipes navigate months and weeks', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final eventRepository = FakeEventRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<EventRepository>.value(value: eventRepository),
          ChangeNotifierProvider(create: (_) => SelectedDay()),
        ],
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: const CalendarPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(eventRepository.watchedRanges, hasLength(1));

    final today = DateTime.now();
    final currentMonth = DateTime(today.year, today.month);
    final nextMonth = DateTime(today.year, today.month + 1);
    final swipeArea = find.byKey(const Key('calendar-swipe-area'));
    final currentMonthPage = find.byKey(
      ValueKey('month-page-${currentMonth.year}-${currentMonth.month}'),
    );
    final initialPageX = tester.getTopLeft(currentMonthPage).dx;

    final partialSwipe = await tester.startGesture(tester.getCenter(swipeArea));
    await partialSwipe.moveBy(const Offset(-20, 0));
    await tester.pump();
    await partialSwipe.moveBy(const Offset(-140, 0));
    await tester.pump();

    expect(tester.getTopLeft(currentMonthPage).dx, lessThan(initialPageX));

    await tester.pump(const Duration(milliseconds: 300));
    await partialSwipe.up();
    await tester.pumpAndSettle();

    expect(
      find.text(DateFormat('MMMM yyyy').format(currentMonth)),
      findsOneWidget,
    );

    await tester.drag(swipeArea, const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(eventRepository.watchedRanges, hasLength(2));
    expect(
      eventRepository.watchedRanges.last,
      isNot(eventRepository.watchedRanges.first),
    );

    expect(
      find.text(DateFormat('MMMM yyyy').format(nextMonth)),
      findsOneWidget,
    );

    await tester.drag(swipeArea, const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(
      find.text(DateFormat('MMMM yyyy').format(currentMonth)),
      findsOneWidget,
    );

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    final nextWeekDate = DateTime(today.year, today.month, today.day + 7);
    final currentWeek = IsoWeekCalculator().fromDate(today);
    final nextWeek = IsoWeekCalculator().fromDate(nextWeekDate);
    final currentWeekPage = find.byKey(
      ValueKey('week-page-${currentWeek.year}-${currentWeek.weekNumber}'),
    );
    final currentWeekTimeScroll = find.descendant(
      of: currentWeekPage,
      matching: find.byType(Scrollable),
    );
    final currentWeekScrollState = tester.state<ScrollableState>(
      currentWeekTimeScroll,
    );
    expect(currentWeekScrollState.position.pixels, weekInitialScrollOffset);

    await tester.drag(currentWeekTimeScroll, const Offset(0, -120));
    await tester.pumpAndSettle();
    final preservedWeekOffset = currentWeekScrollState.position.pixels;
    expect(preservedWeekOffset, greaterThan(weekInitialScrollOffset));

    await tester.drag(swipeArea, const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Week ${nextWeek.weekNumber} · '
        '${DateFormat('MMM yyyy').format(nextWeek.start)}',
      ),
      findsOneWidget,
    );

    final nextWeekPage = find.byKey(
      ValueKey('week-page-${nextWeek.year}-${nextWeek.weekNumber}'),
    );
    final nextWeekTimeScroll = find.descendant(
      of: nextWeekPage,
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(nextWeekTimeScroll).position.pixels,
      moreOrLessEquals(preservedWeekOffset, epsilon: 0.5),
    );
    final settledPageX = tester.getTopLeft(nextWeekPage).dx;

    await tester.tap(find.byTooltip('Previous'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.getTopLeft(nextWeekPage).dx, greaterThan(settledPageX));

    await tester.pumpAndSettle();

    expect(
      find.text(
        'Week ${currentWeek.weekNumber} · '
        '${DateFormat('MMM yyyy').format(currentWeek.start)}',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    await tester.drag(swipeArea, const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    final focusedWeekDate = currentWeek.start.add(const Duration(days: 3));
    final monthAfterFocusedWeek = DateTime(
      focusedWeekDate.year,
      focusedWeekDate.month + 1,
    );
    final firstWeekOfNextMonth = IsoWeekCalculator().fromDate(
      monthAfterFocusedWeek,
    );
    expect(
      find.text(
        'Week ${firstWeekOfNextMonth.weekNumber} · '
        '${DateFormat('MMM yyyy').format(firstWeekOfNextMonth.start)}',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();

    expect(
      find.text(DateFormat('MMMM yyyy').format(monthAfterFocusedWeek)),
      findsOneWidget,
    );
  });
}
