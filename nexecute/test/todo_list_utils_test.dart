import 'package:nexecute/models/todo_item.dart';
import 'package:nexecute/tasks/todo_list_utils.dart';
import 'package:test/test.dart';

void main() {
  TodoItem todo({
    required String id,
    required bool completed,
    required DateTime created,
    DateTime? completedAt,
  }) => TodoItem(
    id: id,
    title: id,
    isCompleted: completed,
    createdAt: created,
    updatedAt: completedAt ?? created,
    completedAt: completedAt,
  );

  test('active todos exclude completed items and use creation order', () {
    final first = todo(
      id: 'first',
      completed: false,
      created: DateTime(2026, 8, 22),
    );
    final second = todo(
      id: 'second',
      completed: false,
      created: DateTime(2026, 8, 23),
    );
    final done = todo(
      id: 'done',
      completed: true,
      created: DateTime(2026, 8, 21),
    );

    expect(activeTodos([second, done, first]), [first, second]);
  });

  test('completed todos show most recently completed first', () {
    final earlier = todo(
      id: 'earlier',
      completed: true,
      created: DateTime(2026, 8, 20),
      completedAt: DateTime(2026, 8, 22),
    );
    final later = todo(
      id: 'later',
      completed: true,
      created: DateTime(2026, 8, 21),
      completedAt: DateTime(2026, 8, 23),
    );

    expect(completedTodos([earlier, later]), [later, earlier]);
  });
}
