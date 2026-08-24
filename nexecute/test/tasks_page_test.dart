import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/models/todo_item.dart';
import 'package:nexecute/tasks/tasks_page.dart';
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';

void main() {
  TodoItem todo({required String id, required bool completed}) => TodoItem(
    id: id,
    title: id,
    isCompleted: completed,
    createdAt: DateTime(2026, 8, 23),
    updatedAt: DateTime(2026, 8, 23),
    completedAt: completed ? DateTime(2026, 8, 23) : null,
  );

  Widget appWith(List<TodoItem> todos) => Provider<List<TodoItem>>.value(
    value: todos,
    child: MaterialApp(
      theme: AppThemes.forPreset(AppThemePreset.neutral),
      home: const Scaffold(body: TasksPage()),
    ),
  );

  testWidgets('shows active tasks and hides completed tasks initially', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWith([
        todo(id: 'Active task', completed: false),
        todo(id: 'Finished task', completed: true),
      ]),
    );

    expect(find.text('1 task open'), findsOneWidget);
    expect(find.text('Active task'), findsOneWidget);
    expect(find.text('Completed (1)'), findsOneWidget);
    expect(find.text('Finished task').hitTestable(), findsNothing);

    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Finished task').hitTestable(), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no active tasks', (
    tester,
  ) async {
    await tester.pumpWidget(appWith(const []));

    expect(find.text('0 tasks open'), findsOneWidget);
    expect(find.text('Nothing to do'), findsOneWidget);
  });

  testWidgets('renders active tasks as separate card-like items', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWith([
        todo(id: 'First task', completed: false),
        todo(id: 'Second task', completed: false),
      ]),
    );

    final first = find.byKey(const ValueKey('todo-surface-First task'));
    final second = find.byKey(const ValueKey('todo-surface-Second task'));

    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    expect(tester.getTopLeft(second).dy - tester.getBottomLeft(first).dy, 8);
    expect(find.byTooltip('Edit task'), findsNWidgets(2));
  });

  for (final preset in AppThemePreset.values) {
    testWidgets('renders under the ${preset.name} theme', (tester) async {
      await tester.pumpWidget(
        Provider<List<TodoItem>>.value(
          value: const [],
          child: MaterialApp(
            theme: AppThemes.forPreset(preset),
            home: const Scaffold(body: TasksPage()),
          ),
        ),
      );

      expect(find.text('Nothing to do'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
