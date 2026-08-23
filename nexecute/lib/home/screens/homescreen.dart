import 'package:flutter/material.dart';
import 'package:nexecute/home/bottomsheets/item_editor.dart';
import 'package:nexecute/home/widgets/quicxecs.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/home_tab_index.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/selected_day.dart';
import 'package:nexecute/shared/drawer.dart';
import 'package:nexecute/tasks/tasks_page.dart';
import 'package:nexecute/tasks/todo_editor_sheet.dart';
import 'package:nexecute/ui/calendar/calendar.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _titles = ['Calendar', 'Tasks', 'Notes'];

  @override
  Widget build(BuildContext context) {
    final tab = context.watch<HomeTabIndex>();

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: Text(_titles[tab.idx])),
        drawer: const MainDrawer(),
        resizeToAvoidBottomInset: true,
        body: IndexedStack(
          index: tab.idx,
          children: const [CalendarPage(), TasksPage(), Quicxecs()],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab.idx,
          onDestinationSelected: tab.changeIndex,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Calendar',
            ),
            NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist_rounded),
              label: 'Tasks',
            ),
            NavigationDestination(
              icon: Icon(Icons.sticky_note_2_outlined),
              selectedIcon: Icon(Icons.sticky_note_2_rounded),
              label: 'Notes',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _createItem(context, tab.idx),
          tooltip: _fabLabel(tab.idx),
          child: Icon(_fabIcon(tab.idx)),
        ),
      ),
    );
  }

  void _createItem(BuildContext context, int index) {
    switch (index) {
      case 0:
        final selectedDay = context.read<SelectedDay>().selectedDay;
        final now = DateTime.now();
        final startTime = DateTime(
          selectedDay.year,
          selectedDay.month,
          selectedDay.day,
          now.hour,
          now.minute,
          now.second,
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

  IconData _fabIcon(int index) => switch (index) {
    0 => Icons.event_outlined,
    1 => Icons.add_task_rounded,
    _ => Icons.note_add_outlined,
  };
}
