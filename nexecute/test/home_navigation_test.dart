import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/home/screens/homescreen.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/home_tab_index.dart';
import 'package:nexecute/models/note_folder.dart';
import 'package:nexecute/models/notes_controller.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/selected_day.dart';
import 'package:nexecute/models/tag.dart' as models;
import 'package:nexecute/models/todo_item.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/shared/adaptive_navigation_shell.dart';
import 'package:nexecute/themes.dart';
import 'package:nexecute/ui/calendar/calendar.dart';
import 'package:provider/provider.dart';

import 'support/fake_event_repository.dart';

void main() {
  test('classifies compact, medium, and expanded widths', () {
    expect(AppLayoutBreakpoints.fromWidth(599), AppLayoutClass.compact);
    expect(AppLayoutBreakpoints.fromWidth(600), AppLayoutClass.medium);
    expect(AppLayoutBreakpoints.fromWidth(839), AppLayoutClass.medium);
    expect(AppLayoutBreakpoints.fromWidth(840), AppLayoutClass.expanded);
  });

  testWidgets(
    'compact layout switches destinations and keeps the drawer reachable',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      await _pumpHome(tester);

      expect(find.byTooltip('New note'), findsOneWidget);
      expect(find.text('New note'), findsNothing);
      expect(find.byType(NavigationDestination), findsNWidgets(3));
      expect(find.byType(NavigationRail), findsNothing);
      expect(tester.getSize(find.byType(NavigationBar)).height, 64);

      await tester.tap(find.byIcon(Icons.checklist_outlined));
      await tester.pumpAndSettle();

      expect(find.byTooltip('New task'), findsOneWidget);
      expect(find.text('New task'), findsNothing);
      expect(find.text('0 tasks open'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pumpAndSettle();

      expect(find.byTooltip('New event'), findsOneWidget);
      expect(find.text('New event'), findsNothing);
      expect(find.byTooltip('Open navigation menu'), findsOneWidget);
      expect(find.byKey(const Key('calendar-toolbar')), findsOneWidget);

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      expect(find.text('Nexecute'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);

      await tester.tapAt(const Offset(380, 400));
      await tester.pumpAndSettle();

      expect(find.byTooltip('New event'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('medium layout uses a labeled navigation rail', (tester) async {
    _setViewport(tester, const Size(700, 900));
    await _pumpHome(tester);

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const Key('adaptive-navigation-rail-shell')), findsOne);

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(rail.labelType, NavigationRailLabelType.all);
    expect(rail.selectedIndex, 2);
    expect(find.text('Calendar'), findsWidgets);
    expect(find.text('Tasks'), findsWidgets);
    expect(find.text('Notes'), findsWidgets);

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();

    expect(find.byTooltip('New event'), findsOneWidget);
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded layout uses an extended navigation rail', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 900));
    await _pumpHome(tester);

    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(rail.labelType, NavigationRailLabelType.none);
    expect(rail.selectedIndex, 2);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Notes'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('destination and calendar state survive live resizing', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 900));
    await _pumpHome(tester);

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    _expectCalendarWeekSelected(tester);

    tester.view.physicalSize = const Size(700, 900);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      0,
    );
    _expectCalendarWeekSelected(tester);

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();

    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isTrue,
    );
    _expectCalendarWeekSelected(tester);

    tester.view.physicalSize = const Size(390, 900);
    await tester.pumpAndSettle();

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    _expectCalendarWeekSelected(tester);
    expect(tester.takeException(), isNull);
  });
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _pumpHome(WidgetTester tester) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeTabIndex()),
        ChangeNotifierProvider(create: (_) => SelectedDay()),
        ChangeNotifierProvider(create: (_) => NotesController()),
        Provider<EventRepository>.value(value: FakeEventRepository()),
        Provider<DataState<List<TodoItem>>>.value(value: const DataEmpty([])),
        Provider<DataState<List<Quicxec>>>.value(value: const DataEmpty([])),
        Provider<DataState<List<NoteFolder>>>.value(value: const DataEmpty([])),
        Provider<DataState<models.Tags>>.value(value: DataEmpty(models.Tags())),
      ],
      child: MaterialApp(
        theme: AppThemes.forPreset(AppThemePreset.midnight),
        home: const HomeScreen(),
      ),
    ),
  );
}

void _expectCalendarWeekSelected(WidgetTester tester) {
  final selector = tester.widget<SegmentedButton<CalendarViewMode>>(
    find.byType(SegmentedButton<CalendarViewMode>),
  );
  expect(selector.selected, {CalendarViewMode.week});
}
