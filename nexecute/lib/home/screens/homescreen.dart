import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexecute/home/bottomsheets/item_editor.dart';
import 'package:nexecute/home/widgets/quicxecs.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/home_tab_index.dart';
import 'package:nexecute/models/notes_controller.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/selected_day.dart';
import 'package:nexecute/shared/adaptive_navigation_shell.dart';
import 'package:nexecute/shared/app_shortcuts.dart';
import 'package:nexecute/shared/drawer.dart';
import 'package:nexecute/shared/macos_app_menu_bar.dart';
import 'package:nexecute/tasks/tasks_page.dart';
import 'package:nexecute/tasks/todo_editor_sheet.dart';
import 'package:nexecute/ui/calendar/calendar.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _destinations = [
    AdaptiveNavigationItem(
      label: 'Calendar',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
    ),
    AdaptiveNavigationItem(
      label: 'Tasks',
      icon: Icons.checklist_outlined,
      selectedIcon: Icons.checklist_rounded,
    ),
    AdaptiveNavigationItem(
      label: 'Notes',
      icon: Icons.sticky_note_2_outlined,
      selectedIcon: Icons.sticky_note_2_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tab = context.watch<HomeTabIndex>();
    final tabIndex = tab.index;

    return Shortcuts(
      shortcuts: AppShortcutBindings.home,
      child: Actions(
        actions: {
          SelectDestinationIntent: CallbackAction<SelectDestinationIntent>(
            onInvoke: (intent) {
              _selectDestination(context, tab, intent.index);
              return null;
            },
          ),
          CreateItemIntent: CallbackAction<CreateItemIntent>(
            onInvoke: (_) {
              _createItemIfAllowed(context, tab.index);
              return null;
            },
          ),
          OpenSearchIntent: CallbackAction<OpenSearchIntent>(
            onInvoke: (_) {
              _openRoute(context, '/search');
              return null;
            },
          ),
        },
        child: Builder(
          builder:
              (commandContext) => MacosAppMenuBar(
                newItemLabel: _menuNewItemLabel(tabIndex),
                onNewItem:
                    () => _createItemIfAllowed(commandContext, tab.index),
                onSelectDestination:
                    (index) => _selectDestination(commandContext, tab, index),
                onSearch: () => _openRoute(commandContext, '/search'),
                onAssistant: () => _openRoute(commandContext, '/assistant'),
                onSettings: () => _openRoute(commandContext, '/settings'),
                onShowKeyboardShortcuts:
                    () => _showKeyboardShortcuts(commandContext),
                child: FocusScope(
                  key: const Key('home-shortcut-focus'),
                  autofocus: true,
                  child: FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: AdaptiveNavigationShell(
                      selectedIndex: tabIndex,
                      onDestinationSelected: tab.select,
                      destinations: _destinations,
                      appBar: AppBar(
                        title: Text(_destinations[tabIndex].label),
                      ),
                      drawer: const MainDrawer(),
                      persistentMenu: const PersistentMainMenu(),
                      persistentMenuWidth: PersistentMainMenu.width,
                      body: IndexedStack(
                        index: tabIndex,
                        children: const [
                          CalendarPage(),
                          TasksPage(),
                          Quicxecs(),
                        ],
                      ),
                      floatingActionButton: Semantics(
                        key: const Key('create-shortcut-semantics'),
                        container: true,
                        hint: 'Shortcut ${AppShortcutLabels.create}',
                        child: FloatingActionButton(
                          onPressed: () => _createItem(context, tabIndex),
                          tooltip: _fabLabel(tabIndex),
                          child: Icon(_fabIcon(tabIndex)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }

  void _selectDestination(BuildContext context, HomeTabIndex tab, int index) {
    if (canInvokeGlobalAppShortcut(context)) tab.select(index);
  }

  void _openRoute(BuildContext context, String routeName) {
    if (canInvokeGlobalAppShortcut(context)) {
      Navigator.pushNamed(context, routeName);
    }
  }

  void _showKeyboardShortcuts(BuildContext context) {
    if (canInvokeGlobalAppShortcut(context)) {
      unawaited(showKeyboardShortcutsDialog(context));
    }
  }

  void _createItemIfAllowed(BuildContext context, int index) {
    if (canInvokeGlobalAppShortcut(context)) _createItem(context, index);
  }

  void _createItem(BuildContext context, int index) {
    switch (index) {
      case 0:
        final selectedDay = context.read<SelectedDay>().selectedDay;
        final startTime = DateTime(
          selectedDay.year,
          selectedDay.month,
          selectedDay.day,
          9,
        );
        showItemEditor(
          context,
          event: Event(
            id: '',
            title: '',
            startTime: startTime,
            endTime: startTime.add(const Duration(hours: 1)),
          ),
        );
        break;
      case 1:
        showTodoEditor(context);
        break;
      case 2:
        showItemEditor(
          context,
          quicxec: Quicxec(
            id: '',
            text: '',
            created: DateTime.now(),
            title: '',
            folderId: context.read<NotesController>().creationFolderId,
          ),
        );
        break;
    }
  }

  String _fabLabel(int index) => switch (index) {
    0 => 'New event',
    1 => 'New task',
    _ => 'New note',
  };

  String _menuNewItemLabel(int index) => switch (index) {
    0 => 'New Event',
    1 => 'New Task',
    _ => 'New Note',
  };

  IconData _fabIcon(int index) => switch (index) {
    0 => Icons.event_outlined,
    1 => Icons.add_task_rounded,
    _ => Icons.note_add_outlined,
  };
}
