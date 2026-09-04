import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/home/bottomsheets/item_editor_sheet.dart';
import 'package:nexecute/home/screens/homescreen.dart';
import 'package:nexecute/models/app_theme_controller.dart';
import 'package:nexecute/models/calendar_settings_controller.dart';
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
import 'package:nexecute/shared/app_brand_icon.dart';
import 'package:nexecute/shared/app_shortcuts.dart';
import 'package:nexecute/shared/drawer.dart';
import 'package:nexecute/services/auth.dart';
import 'package:nexecute/themes.dart';
import 'package:nexecute/ui/calendar/calendar.dart';
import 'package:provider/provider.dart';

import 'support/fake_event_repository.dart';
import 'support/fake_ai_dependencies.dart';
import 'support/fake_auth_clients.dart';

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

      expect(find.text('Nexecute'), findsNothing);
      expect(find.byKey(const Key('app-drawer-icon')), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);

      await tester.tapAt(const Offset(380, 400));
      await tester.pumpAndSettle();

      expect(find.byTooltip('New event'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'medium layout uses the persistent workspace with a compact rail',
    (tester) async {
      _setViewport(tester, const Size(700, 900));
      await _pumpHome(tester);

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byKey(const Key('persistent-main-menu')), findsOneWidget);
      expect(
        find.byKey(const Key('medium-persistent-navigation-rail')),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(const Key('persistent-main-menu'))).width,
        PersistentMainMenu.compactWidth,
      );
      expect(find.byKey(const Key('medium-section-divider-0')), findsOneWidget);
      expect(find.byKey(const Key('medium-section-divider-1')), findsOneWidget);
      expect(_selectedDestination(tester), 2);
      expect(find.text('Calendar'), findsWidgets);
      expect(find.text('Tasks'), findsWidgets);
      expect(find.text('Notes'), findsWidgets);
      expect(find.text('Assistant'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byTooltip('Search'), findsOneWidget);
      expect(find.byTooltip('Keyboard shortcuts'), findsOneWidget);
      expect(find.byTooltip('Open navigation menu'), findsNothing);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      final orderedItems = [
        find.byKey(const ValueKey('desktop-destination-0')),
        find.byKey(const ValueKey('desktop-destination-1')),
        find.byKey(const ValueKey('desktop-destination-2')),
        find.byKey(const Key('medium-section-divider-0')),
        find.byKey(const Key('medium-search-action')),
        find.byKey(const ValueKey('desktop-destination-3')),
        find.byKey(const ValueKey('desktop-destination-4')),
        find.byKey(const ValueKey('desktop-destination-5')),
        find.byKey(const Key('medium-section-divider-1')),
        find.byKey(const ValueKey('desktop-destination-6')),
        find.byKey(const ValueKey('desktop-destination-7')),
        find.byKey(const Key('medium-keyboard-shortcuts-action')),
      ];
      final itemTops = [
        for (final item in orderedItems) tester.getTopLeft(item).dy,
      ];
      expect(itemTops, orderedEquals([...itemTops]..sort()));

      expect(find.text('Nexecute'), findsNothing);
      final appIcon = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const Key('app-shell-icon')),
          matching: find.byType(Image),
        ),
      );
      expect(
        appIcon.image,
        isA<AssetImage>().having(
          (image) => image.assetName,
          'asset name',
          NexecuteAppIcon.assetName,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('desktop-destination-0')));
      await tester.pumpAndSettle();

      expect(_selectedDestination(tester), 0);
      expect(find.byTooltip('New event'), findsOneWidget);
      expect(find.byKey(const Key('calendar-toolbar')), findsOneWidget);
      expect(
        find.byKey(const Key('calendar-side-by-side-layout')),
        findsNothing,
      );

      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('desktop-global-search-dialog')),
        findsOneWidget,
      );

      Navigator.pop(
        tester.element(find.byKey(const Key('desktop-global-search-dialog'))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('desktop-destination-7')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('desktop-settings-tab')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('expanded layout keeps the app menu visible beside content', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 900));
    await _pumpHome(tester);

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byKey(const Key('persistent-main-menu')), findsOneWidget);
    expect(find.byKey(const Key('desktop-destination-selector')), findsNothing);
    expect(find.byKey(const Key('desktop-source-list')), findsOneWidget);
    expect(find.byKey(const Key('desktop-page-title')), findsOneWidget);
    expect(find.byKey(const Key('desktop-create-command')), findsOneWidget);
    expect(
      find.byKey(const Key('desktop-global-search-field')),
      findsOneWidget,
    );
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('Open navigation menu'), findsNothing);
    expect(find.text('Nexecute'), findsNothing);
    expect(find.byKey(const Key('app-shell-icon')), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Assistant'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Keyboard shortcuts'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(_selectedDestination(tester), 2);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Notes'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('desktop-destination-0')));
    await tester.pumpAndSettle();

    expect(_selectedDestination(tester), 0);
    expect(find.byKey(const Key('persistent-main-menu')), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byKey(const Key('calendar-side-by-side-layout')), findsOne);
    final calendar = tester.getRect(
      find.byKey(const Key('calendar-swipe-area')),
    );
    final agenda = tester.getRect(
      find.byKey(const Key('selected-day-agenda-container')),
    );
    expect(calendar.right, lessThanOrEqualTo(agenda.left));

    await tester.tap(find.byKey(const Key('desktop-global-search-field')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('desktop-global-search-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('unified-search-field')), findsOneWidget);

    Navigator.pop(
      tester.element(find.byKey(const Key('desktop-global-search-dialog'))),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('persistent-main-menu')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop note editor gives spare height to the description', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 900));
    await _pumpHome(tester);

    await tester.tap(find.byKey(const Key('desktop-create-command')));
    await tester.pumpAndSettle();

    final description = find.byKey(const Key('note-description-field'));
    final editableText = tester.widget<EditableText>(
      find.descendant(of: description, matching: find.byType(EditableText)),
    );
    final editorSurface = tester.getRect(
      find.byKey(const Key('desktop-item-editor-surface')),
    );
    final actionBar = tester.getRect(
      find.byKey(const Key('item-editor-sticky-actions')),
    );

    expect(editableText.expands, isTrue);
    expect(tester.getSize(description).height, greaterThan(300));
    expect(actionBar.bottom, editorSurface.bottom);
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
    expect(find.byType(NavigationRail), findsNothing);
    expect(
      find.byKey(const Key('medium-persistent-navigation-rail')),
      findsOneWidget,
    );
    expect(_selectedDestination(tester), 0);
    _expectCalendarWeekSelected(tester);

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byKey(const Key('persistent-main-menu')), findsOneWidget);
    expect(_selectedDestination(tester), 0);
    expect(find.byKey(const Key('calendar-side-by-side-layout')), findsOne);
    _expectCalendarWeekSelected(tester);

    tester.view.physicalSize = const Size(390, 900);
    await tester.pumpAndSettle();

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(find.byKey(const Key('calendar-side-by-side-layout')), findsNothing);
    _expectCalendarWeekSelected(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop secondary destinations switch tabs without routes', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 900));
    await _pumpHome(tester);
    final navigator = Navigator.of(
      tester.element(find.byKey(const Key('desktop-tab-host'))),
    );

    await tester.tap(find.byKey(const ValueKey('desktop-destination-3')));
    await tester.pumpAndSettle();

    expect(_selectedDestination(tester), 3);
    expect(
      find.byKey(const Key('desktop-assistant-tab')).hitTestable(),
      findsOneWidget,
    );
    expect(find.byKey(const Key('persistent-main-menu')), findsOneWidget);
    expect(find.byKey(const Key('desktop-create-command')), findsNothing);
    expect(navigator.canPop(), isFalse);

    await tester.tap(find.byKey(const ValueKey('desktop-destination-4')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('desktop-tags-tab')).hitTestable(),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('desktop-destination-5')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('desktop-trash-tab')).hitTestable(),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('desktop-destination-6')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('desktop-profile-tab')).hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Not signed in'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('desktop-destination-3')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(_selectedDestination(tester), 7);
    expect(
      find.byKey(const Key('desktop-settings-tab')).hitTestable(),
      findsOneWidget,
    );
    expect(find.byKey(const Key('persistent-main-menu')), findsOneWidget);
    expect(navigator.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop shortcuts navigate, create, search, and respect focus', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 900));
    await _pumpHome(tester);

    await _pressControlShortcut(tester, LogicalKeyboardKey.digit1);
    expect(_selectedDestination(tester), 0);

    await _pressControlShortcut(tester, LogicalKeyboardKey.digit2);
    expect(_selectedDestination(tester), 1);

    await _pressControlShortcut(tester, LogicalKeyboardKey.digit3);
    expect(_selectedDestination(tester), 2);

    await tester.tap(find.widgetWithText(TextField, 'Search notes'));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    await _pressControlShortcut(tester, LogicalKeyboardKey.digit1);
    expect(_selectedDestination(tester), 2);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await _pressControlShortcut(tester, LogicalKeyboardKey.keyN);
    expect(find.byType(ItemEditorSheet), findsOneWidget);
    expect(find.byKey(const Key('desktop-item-editor-dialog')), findsOneWidget);

    await _pressControlShortcut(tester, LogicalKeyboardKey.digit1);
    expect(_selectedDestination(tester), 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(ItemEditorSheet), findsNothing);

    await _pressControlShortcut(tester, LogicalKeyboardKey.keyK);
    expect(
      find.byKey(const Key('desktop-global-search-dialog')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shortcut help and shell focus order are discoverable', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 900));
    final semantics = tester.ensureSemantics();
    await _pumpHome(tester);

    expect(_focusOrder(tester, 'navigation-focus-order'), 1);
    expect(_focusOrder(tester, 'content-focus-order'), 2);
    expect(_focusOrder(tester, 'create-focus-order'), 3);
    final createSemantics = tester.getSemantics(
      find.byKey(const Key('create-shortcut-semantics')),
    );
    expect(createSemantics.getSemanticsData().hint, contains('Ctrl+N'));

    expect(find.text('Keyboard shortcuts'), findsOneWidget);
    expect(find.text(AppShortcutLabels.search), findsOneWidget);

    await tester.tap(find.text('Keyboard shortcuts'));
    await tester.pumpAndSettle();
    expect(find.text('Save or confirm'), findsOneWidget);
    expect(find.text(AppShortcutLabels.save), findsOneWidget);
    expect(find.text('Focus Assistant composer'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  const representativeSizes = <String, Size>{
    'phone': Size(390, 844),
    'tablet': Size(700, 900),
    'laptop': Size(1000, 800),
    'wide': Size(1600, 1000),
  };
  for (final preset in AppThemePreset.values) {
    for (final size in representativeSizes.entries) {
      testWidgets(
        '${preset.name} theme has no feature overflow at ${size.key} size',
        (tester) async {
          _setViewport(tester, size.value);
          await _pumpHome(tester, themePreset: preset);

          await tester.tap(find.byIcon(Icons.calendar_month_outlined));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('calendar-toolbar')), findsOne);

          await tester.tap(find.byIcon(Icons.checklist_outlined));
          await tester.pumpAndSettle();
          expect(find.text('Nothing to do'), findsOneWidget);

          await tester.tap(find.byIcon(Icons.sticky_note_2_outlined));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('notes-knowledge-base-root')), findsOne);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _pumpHome(
  WidgetTester tester, {
  AppThemePreset themePreset = AppThemePreset.midnight,
}) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeTabIndex()),
        ChangeNotifierProvider(create: (_) => SelectedDay()),
        ChangeNotifierProvider(create: (_) => NotesController()),
        ChangeNotifierProvider(create: (_) => AppThemeController()),
        ChangeNotifierProvider(create: (_) => CalendarSettingsController()),
        Provider<EventRepository>.value(value: FakeEventRepository()),
        Provider<AuthService>(
          create:
              (_) => AuthService(
                firebaseAuthClient: FakeFirebaseAuthClient(),
                googleAuthClient: FakeGoogleAuthClient(),
              ),
        ),
        Provider<AiAssistantRepository>(
          create: (_) => FakeAiAssistantRepository(),
        ),
        Provider<AiConnectionProfileStore>(
          create: (_) => FakeAiConnectionProfileStore(),
          dispose: (_, store) => store.dispose(),
        ),
        Provider<AiConversationStore>(
          create: (_) => FakeAiConversationStore(),
          dispose: (_, store) => store.dispose(),
        ),
        Provider<AiApplicationContextReadService>(
          create: (_) => FakeAiApplicationContextReadService(),
        ),
        Provider<AiCredentialStore>(create: (_) => FakeAiCredentialStore()),
        Provider<DataState<List<TodoItem>>>.value(value: const DataEmpty([])),
        Provider<DataState<List<Quicxec>>>.value(value: const DataEmpty([])),
        Provider<DataState<List<NoteFolder>>>.value(value: const DataEmpty([])),
        Provider<DataState<models.Tags>>.value(value: DataEmpty(models.Tags())),
      ],
      child: MaterialApp(
        theme: AppThemes.forPreset(themePreset),
        routes: {
          '/search':
              (_) => const Scaffold(
                key: Key('shortcut-search-route'),
                body: Text('Search route'),
              ),
        },
        home: const HomeScreen(),
      ),
    ),
  );
}

int _selectedDestination(WidgetTester tester) {
  final desktopMenu = find.byType(PersistentMainMenu);
  if (desktopMenu.evaluate().isNotEmpty) {
    return tester.widget<PersistentMainMenu>(desktopMenu).selectedIndex;
  }
  return tester
      .widget<NavigationRail>(find.byType(NavigationRail))
      .selectedIndex!;
}

double _focusOrder(WidgetTester tester, String key) =>
    (tester.widget<FocusTraversalOrder>(find.byKey(Key(key))).order
            as NumericFocusOrder)
        .order;

Future<void> _pressControlShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void _expectCalendarWeekSelected(WidgetTester tester) {
  final selector = tester.widget<SegmentedButton<CalendarViewMode>>(
    find.byType(SegmentedButton<CalendarViewMode>),
  );
  expect(selector.selected, {CalendarViewMode.week});
}
