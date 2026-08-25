import 'package:nexecute/models/todo_item.dart';
import 'package:nexecute/repositories/firestore/todo_document_mapper.dart';
import 'package:test/test.dart';

void main() {
  test('reads a todo from Firestore-compatible data', () {
    final createdAt = DateTime(2026, 8, 23, 9);
    final completedAt = DateTime(2026, 8, 24, 10);

    final todo = TodoDocumentMapper.fromMap('todo-1', {
      'title': 'Buy groceries',
      'isCompleted': true,
      'createdAt': createdAt,
      'updatedAt': completedAt,
      'completedAt': completedAt,
    });

    expect(todo.id, 'todo-1');
    expect(todo.title, 'Buy groceries');
    expect(todo.isCompleted, isTrue);
    expect(todo.createdAt, createdAt);
    expect(todo.completedAt, completedAt);
  });

  test('uses safe defaults for older or incomplete data', () {
    final todo = TodoDocumentMapper.fromMap('todo-2', const {});

    expect(todo.title, isEmpty);
    expect(todo.isCompleted, isFalse);
    expect(todo.completedAt, isNull);
  });

  test('can clear completion metadata', () {
    final todo = TodoItem(
      id: 'todo-3',
      title: 'Done',
      isCompleted: true,
      createdAt: DateTime(2026, 8, 23),
      updatedAt: DateTime(2026, 8, 23),
      completedAt: DateTime(2026, 8, 23),
    );

    final restored = todo.copyWith(isCompleted: false, clearCompletedAt: true);

    expect(restored.isCompleted, isFalse);
    expect(restored.completedAt, isNull);
  });
}
