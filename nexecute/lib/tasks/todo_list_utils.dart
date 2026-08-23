import 'package:nexecute/models/todo_item.dart';

List<TodoItem> activeTodos(Iterable<TodoItem> todos) {
  final result =
      todos.where((todo) => !todo.isCompleted).toList()
        ..sort((first, second) => first.createdAt.compareTo(second.createdAt));
  return result;
}

List<TodoItem> completedTodos(Iterable<TodoItem> todos) {
  final result =
      todos.where((todo) => todo.isCompleted).toList()..sort((first, second) {
        final firstDate = first.completedAt ?? first.updatedAt;
        final secondDate = second.completedAt ?? second.updatedAt;
        return secondDate.compareTo(firstDate);
      });
  return result;
}
