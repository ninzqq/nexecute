import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/domain/calendar/gregorian_month_calculator.dart';
import 'package:nexecute/home/screens/settingsscreen.dart';
import 'package:nexecute/models/app_theme_controller.dart';
import 'package:nexecute/models/calendar_settings_controller.dart';
import 'package:nexecute/themes.dart';
import 'package:nexecute/ui/calendar/month_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('shows week numbers by default', () async {
    final controller = await CalendarSettingsController.load();

    expect(controller.showWeekNumbers, isTrue);
  });

  test('persists the week-number preference', () async {
    final controller = await CalendarSettingsController.load();

    await controller.setShowWeekNumbers(false);
    final restoredController = await CalendarSettingsController.load();

    expect(restoredController.showWeekNumbers, isFalse);
  });

  testWidgets('month view renders ISO week numbers across a year boundary', (
    tester,
  ) async {
    final month = GregorianMonthCalculator().fromDate(DateTime(2021, 1, 15));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemes.forPreset(AppThemePreset.midnight),
        home: Scaffold(
          body: MonthView(
            month: month,
            selectedDay: DateTime(2021, 1, 15),
            events: const [],
            onDaySelected: (_) {},
            onEventSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('month-week-number-header')), findsOneWidget);
    expect(find.byKey(const Key('month-week-number-2020-53')), findsOneWidget);
    expect(find.byKey(const Key('month-week-number-2021-1')), findsOneWidget);
  });

  testWidgets('month view hides the week-number column when disabled', (
    tester,
  ) async {
    final month = GregorianMonthCalculator().fromDate(DateTime(2021, 1, 15));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemes.forPreset(AppThemePreset.midnight),
        home: Scaffold(
          body: MonthView(
            month: month,
            showWeekNumbers: false,
            selectedDay: DateTime(2021, 1, 15),
            events: const [],
            onDaySelected: (_) {},
            onEventSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('month-week-number-header')), findsNothing);
    expect(find.byKey(const Key('month-week-number-2020-53')), findsNothing);
  });

  testWidgets('settings switch updates and persists the preference', (
    tester,
  ) async {
    final calendarSettings = CalendarSettingsController();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppThemeController()),
          ChangeNotifierProvider.value(value: calendarSettings),
        ],
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: const SettingsScreen(),
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    final switchFinder = find.byKey(const Key('show-week-numbers-switch'));
    expect(switchFinder, findsOneWidget);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(calendarSettings.showWeekNumbers, isFalse);
    final restoredController = await CalendarSettingsController.load();
    expect(restoredController.showWeekNumbers, isFalse);
  });
}
