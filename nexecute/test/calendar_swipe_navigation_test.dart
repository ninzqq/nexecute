import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nexecute/domain/calendar/iso_week_calculator.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/selected_day.dart';
import 'package:nexecute/themes.dart';
import 'package:nexecute/ui/calendar/calendar.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('horizontal swipes navigate months and weeks', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<List<Event>>.value(value: const []),
          ChangeNotifierProvider(create: (_) => SelectedDay()),
        ],
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: const CalendarPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final today = DateTime.now();
    final currentMonth = DateTime(today.year, today.month);
    final nextMonth = DateTime(today.year, today.month + 1);
    final swipeArea = find.byKey(const Key('calendar-swipe-area'));

    await tester.drag(swipeArea, const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(
      find.text(DateFormat('MMMM yyyy').format(nextMonth)),
      findsOneWidget,
    );

    await tester.drag(swipeArea, const Offset(300, 0));
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
    final nextWeek = IsoWeekCalculator().fromDate(nextWeekDate);

    await tester.drag(swipeArea, const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Week ${nextWeek.weekNumber} · '
        '${DateFormat('MMM yyyy').format(nextWeek.start)}',
      ),
      findsOneWidget,
    );
  });
}
