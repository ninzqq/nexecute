import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexecute/ai/presentation/assistant_page.dart';
import 'package:nexecute/home/bottomsheets/item_editor.dart';
import 'package:nexecute/home/screens/settingsscreen.dart';
import 'package:nexecute/home/screens/tagsscreen.dart';
import 'package:nexecute/home/screens/trashscreen.dart';
import 'package:nexecute/home/widgets/quicxecs.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/home_tab_index.dart';
import 'package:nexecute/models/notes_controller.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/selected_day.dart';
import 'package:nexecute/search/unified_search_page.dart';
import 'package:nexecute/profile/profilescreen.dart';
import 'package:nexecute/shared/adaptive_navigation_shell.dart';
import 'package:nexecute/shared/app_shortcuts.dart';
import 'package:nexecute/shared/drawer.dart';
import 'package:nexecute/shared/macos_app_menu_bar.dart';
import 'package:nexecute/tasks/tasks_page.dart';
import 'package:nexecute/tasks/todo_editor_sheet.dart';
import 'package:nexecute/ui/calendar/calendar.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  static const _desktopDestinations = [
    ..._destinations,
    AdaptiveNavigationItem(
      label: 'Assistant',
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome_rounded,
    ),
    AdaptiveNavigationItem(
      label: 'Tags',
      icon: Icons.label_outline_rounded,
      selectedIcon: Icons.label_rounded,
    ),
    AdaptiveNavigationItem(
      label: 'Archive',
      icon: Icons.archive_outlined,
      selectedIcon: Icons.archive_rounded,
    ),
    AdaptiveNavigationItem(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
    AdaptiveNavigationItem(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
    ),
  ];

  int _desktopTabIndex = 2;
  final Set<int> _visitedDesktopTabs = {0, 1, 2};

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
              _openSearch(context);
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
                onSearch:
                    () => _openSearch(
                      commandContext,
                      respectFocusedEditor: false,
                    ),
                onAssistant:
                    () => _openWorkspaceTabOrRoute(
                      commandContext,
                      tab,
                      desktopIndex: 3,
                      mobileRoute: '/assistant',
                    ),
                onSettings:
                    () => _openWorkspaceTabOrRoute(
                      commandContext,
                      tab,
                      desktopIndex: 7,
                      mobileRoute: '/settings',
                    ),
                onShowKeyboardShortcuts:
                    () => _showKeyboardShortcuts(commandContext),
                child: FocusScope(
                  key: const Key('home-shortcut-focus'),
                  autofocus: true,
                  child: FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final desktop =
                            AppLayoutBreakpoints.fromWidth(
                              constraints.maxWidth,
                            ) ==
                            AppLayoutClass.expanded;
                        final activeIndex =
                            desktop ? _desktopTabIndex : tabIndex;
                        return AdaptiveNavigationShell(
                          selectedIndex: tabIndex,
                          onDestinationSelected:
                              (index) => _selectPrimaryTab(tab, index),
                          destinations: _destinations,
                          desktopTitle: _desktopDestinations[activeIndex].label,
                          appBar: AppBar(
                            title: Text(_destinations[tabIndex].label),
                          ),
                          drawer: const MainDrawer(),
                          persistentMenu: PersistentMainMenu(
                            selectedIndex: activeIndex,
                            onDestinationSelected:
                                (index) => _selectDesktopTab(tab, index),
                            destinations: _desktopDestinations,
                            onSearch:
                                () => _openSearch(
                                  context,
                                  respectFocusedEditor: false,
                                ),
                          ),
                          persistentMenuWidth: PersistentMainMenu.width,
                          body: _desktopTabHost(tab, activeIndex),
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
                          desktopToolbarSearch: DesktopGlobalSearchField(
                            onPressed:
                                () => _openSearch(
                                  context,
                                  respectFocusedEditor: false,
                                ),
                          ),
                          desktopPrimaryAction:
                              activeIndex < 3
                                  ? Semantics(
                                    key: const Key('create-shortcut-semantics'),
                                    hint:
                                        'Shortcut ${AppShortcutLabels.create}',
                                    button: true,
                                    child: FilledButton.icon(
                                      key: const Key('desktop-create-command'),
                                      onPressed:
                                          () =>
                                              _createItem(context, activeIndex),
                                      icon: Icon(
                                        _fabIcon(activeIndex),
                                        size: 18,
                                      ),
                                      label: Text(_fabLabel(activeIndex)),
                                    ),
                                  )
                                  : null,
                        );
                      },
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }

  void _selectDestination(BuildContext context, HomeTabIndex tab, int index) {
    if (canInvokeGlobalAppShortcut(context)) {
      _selectPrimaryTab(tab, index, unfocus: false);
    }
  }

  void _selectPrimaryTab(HomeTabIndex tab, int index, {bool unfocus = true}) {
    if (unfocus) FocusManager.instance.primaryFocus?.unfocus();
    tab.select(index);
    if (_desktopTabIndex == index) return;
    setState(() {
      _desktopTabIndex = index;
      _visitedDesktopTabs.add(index);
    });
  }

  void _selectDesktopTab(HomeTabIndex tab, int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (index < 3) tab.select(index);
    if (_desktopTabIndex == index) return;
    setState(() {
      _desktopTabIndex = index;
      _visitedDesktopTabs.add(index);
    });
  }

  void _openWorkspaceTabOrRoute(
    BuildContext context,
    HomeTabIndex tab, {
    required int desktopIndex,
    required String mobileRoute,
  }) {
    if (AppLayoutBreakpoints.fromWidth(MediaQuery.sizeOf(context).width) ==
        AppLayoutClass.expanded) {
      _selectDesktopTab(tab, desktopIndex);
    } else if (canInvokeGlobalAppShortcut(context)) {
      Navigator.pushNamed(context, mobileRoute);
    }
  }

  Widget _desktopTabHost(HomeTabIndex tab, int selectedIndex) => IndexedStack(
    key: const Key('desktop-tab-host'),
    index: selectedIndex,
    children: [
      const CalendarPage(),
      const TasksPage(),
      const Quicxecs(),
      _visitedDesktopTabs.contains(3)
          ? AssistantPage(
            embedded: true,
            onOpenSettings: () => _selectDesktopTab(tab, 7),
          )
          : const SizedBox.shrink(),
      _visitedDesktopTabs.contains(4)
          ? const TagsScreen(embedded: true)
          : const SizedBox.shrink(),
      _visitedDesktopTabs.contains(5)
          ? const TrashScreen(embedded: true)
          : const SizedBox.shrink(),
      _visitedDesktopTabs.contains(6)
          ? const ProfileScreen(embedded: true)
          : const SizedBox.shrink(),
      _visitedDesktopTabs.contains(7)
          ? const SettingsScreen(embedded: true)
          : const SizedBox.shrink(),
    ],
  );

  void _openSearch(BuildContext context, {bool respectFocusedEditor = true}) {
    if (respectFocusedEditor && !canInvokeGlobalAppShortcut(context)) return;

    if (AppLayoutBreakpoints.fromWidth(MediaQuery.sizeOf(context).width) ==
        AppLayoutClass.expanded) {
      final tab = context.read<HomeTabIndex>();
      unawaited(
        showDesktopGlobalSearch(
          context,
          onOpenTags: () => _selectDesktopTab(tab, 4),
        ),
      );
    } else {
      Navigator.pushNamed(context, '/search');
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
