import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/home/bottomsheets/item_editor_sheet.dart';
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
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';

import 'support/fake_event_repository.dart';

void main() {
  testWidgets(
    'macOS menu exposes standard and supported application commands',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await _pumpHome(tester);

      var menuBar = tester.widget<PlatformMenuBar>(
        find.byType(PlatformMenuBar),
      );
      expect(menuBar.menus.map((menu) => menu.label), [
        'Nexecute',
        'File',
        'Edit',
        'Navigate',
        'Window',
        'Help',
      ]);

      var items = _leafItems(menuBar.menus);
      _expectMacShortcut(items['Settings…']!, LogicalKeyboardKey.comma);
      _expectMacShortcut(items['New Note']!, LogicalKeyboardKey.keyN);
      _expectMacShortcut(items['Calendar']!, LogicalKeyboardKey.digit1);
      _expectMacShortcut(items['Tasks']!, LogicalKeyboardKey.digit2);
      _expectMacShortcut(items['Notes']!, LogicalKeyboardKey.digit3);
      _expectMacShortcut(items['Search']!, LogicalKeyboardKey.keyK);
      _expectMacShortcut(
        items['Keyboard Shortcuts…']!,
        LogicalKeyboardKey.slash,
      );
      expect(items['Undo']!.onSelectedIntent, isA<UndoTextIntent>());
      expect(items['Redo']!.onSelectedIntent, isA<RedoTextIntent>());
      expect(items['Cut']!.onSelectedIntent, isA<CopySelectionTextIntent>());
      expect(items['Copy']!.onSelectedIntent, isA<CopySelectionTextIntent>());
      expect(items['Paste']!.onSelectedIntent, isA<PasteTextIntent>());
      expect(items['Select All']!.onSelectedIntent, isA<SelectAllTextIntent>());

      await tester.tap(find.widgetWithText(TextField, 'Search notes'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Search notes'),
        'menu edit command',
      );
      final editableFocusContext = FocusManager.instance.primaryFocus!.context!;
      Actions.invoke(
        editableFocusContext,
        items['Select All']!.onSelectedIntent!,
      );
      await tester.pump();
      final editableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(
        editableText.controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 17),
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      items['New Note']!.onSelected!();
      await tester.pumpAndSettle();
      expect(find.byType(ItemEditorSheet), findsOneWidget);

      items['Calendar']!.onSelected!();
      await tester.pumpAndSettle();
      expect(_selectedDestination(tester), 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      items['Calendar']!.onSelected!();
      await tester.pumpAndSettle();
      expect(_selectedDestination(tester), 0);

      menuBar = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar));
      items = _leafItems(menuBar.menus);
      expect(items, contains('New Event'));
      items['Search']!.onSelected!();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menu-search-route')), findsOneWidget);

      Navigator.pop(tester.element(find.byKey(const Key('menu-search-route'))));
      await tester.pumpAndSettle();
      items['Assistant']!.onSelected!();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menu-assistant-route')), findsOneWidget);

      Navigator.pop(
        tester.element(find.byKey(const Key('menu-assistant-route'))),
      );
      await tester.pumpAndSettle();
      items['Settings…']!.onSelected!();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menu-settings-route')), findsOneWidget);

      Navigator.pop(
        tester.element(find.byKey(const Key('menu-settings-route'))),
      );
      await tester.pumpAndSettle();
      items['Keyboard Shortcuts…']!.onSelected!();
      await tester.pumpAndSettle();
      expect(find.text('Save or confirm'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );
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
        routes: {
          '/search':
              (_) => const Scaffold(
                key: Key('menu-search-route'),
                body: Text('Search route'),
              ),
          '/assistant':
              (_) => const Scaffold(
                key: Key('menu-assistant-route'),
                body: Text('Assistant route'),
              ),
          '/settings':
              (_) => const Scaffold(
                key: Key('menu-settings-route'),
                body: Text('Settings route'),
              ),
        },
        home: const HomeScreen(),
      ),
    ),
  );
}

Map<String, PlatformMenuItem> _leafItems(List<PlatformMenuItem> roots) {
  final result = <String, PlatformMenuItem>{};

  void visit(PlatformMenuItem item) {
    if (item is PlatformMenu) {
      for (final child in item.menus) {
        visit(child);
      }
      return;
    }
    if (item is PlatformMenuItemGroup) {
      for (final member in item.members) {
        visit(member);
      }
      return;
    }
    if (item.label.isNotEmpty) result[item.label] = item;
  }

  for (final root in roots) {
    visit(root);
  }
  return result;
}

void _expectMacShortcut(PlatformMenuItem item, LogicalKeyboardKey key) {
  final shortcut = item.shortcut! as SingleActivator;
  expect(shortcut.trigger, key);
  expect(shortcut.meta, isTrue);
  expect(shortcut.control, isFalse);
}

int _selectedDestination(WidgetTester tester) =>
    tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex!;
