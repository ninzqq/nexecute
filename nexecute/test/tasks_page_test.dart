import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/todo_item.dart';
import 'package:nexecute/repositories/todo_repository.dart';
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

  Widget appWithState(
    DataState<List<TodoItem>> state, {
    TodoRepository? repository,
  }) => MultiProvider(
    providers: [
      Provider<DataState<List<TodoItem>>>.value(value: state),
      Provider<TodoRepository>.value(
        value: repository ?? _FakeTodoRepository(),
      ),
    ],
    child: MaterialApp(
      theme: AppThemes.forPreset(AppThemePreset.neutral),
      home: const Scaffold(body: TasksPage()),
    ),
  );

  Widget appWith(List<TodoItem> todos, {TodoRepository? repository}) =>
      appWithState(
        todos.isEmpty ? DataEmpty(todos) : DataReady(todos),
        repository: repository,
      );

  testWidgets('keeps loading distinct from an empty task list', (tester) async {
    await tester.pumpWidget(appWithState(const DataLoading<List<TodoItem>>()));

    expect(find.text('Loading tasks…'), findsOneWidget);
    expect(find.text('Nothing to do'), findsNothing);
  });

  testWidgets('shows the authentication state separately', (tester) async {
    await tester.pumpWidget(
      appWithState(const DataUnauthenticated<List<TodoItem>>()),
    );

    expect(find.text('Sign in required'), findsOneWidget);
    expect(find.text('Nothing to do'), findsNothing);
  });

  testWidgets('keeps failures distinct from an empty task list', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWithState(DataFailure<List<TodoItem>>(StateError('offline'))),
    );

    expect(find.text('Could not load tasks'), findsOneWidget);
    expect(find.text('Nothing to do'), findsNothing);
  });

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

  testWidgets('completion uses the injected task repository', (tester) async {
    final repository = _FakeTodoRepository();
    final activeTodo = todo(id: 'Active task', completed: false);

    await tester.pumpWidget(appWith([activeTodo], repository: repository));

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(repository.completedTodo, same(activeTodo));
    expect(repository.completedValue, isTrue);
  });

  for (final preset in AppThemePreset.values) {
    testWidgets('renders under the ${preset.name} theme', (tester) async {
      await tester.pumpWidget(
        Provider<DataState<List<TodoItem>>>.value(
          value: const DataEmpty([]),
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

class _FakeTodoRepository implements TodoRepository {
  TodoItem? completedTodo;
  bool? completedValue;

  @override
  Stream<DataState<List<TodoItem>>> watchTodos() =>
      Stream.value(const DataEmpty([]));

  @override
  Future<void> addTodo(String title) async {}

  @override
  Future<void> updateTitle(TodoItem todo, String title) async {}

  @override
  Future<void> setCompleted(TodoItem todo, bool isCompleted) async {
    completedTodo = todo;
    completedValue = isCompleted;
  }

  @override
  Future<void> deleteTodo(TodoItem todo) async {}

  @override
  Future<void> restoreTodo(TodoItem todo) async {}
}
