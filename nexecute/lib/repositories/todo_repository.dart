import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/models/todo_item.dart';
import 'package:nexecute/services/auth.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

abstract interface class TodoRepository {
  Stream<List<TodoItem>> watchTodos();

  Future<void> addTodo(String title);

  Future<void> updateTitle(TodoItem todo, String title);

  Future<void> setCompleted(TodoItem todo, bool isCompleted);

  Future<void> deleteTodo(TodoItem todo);

  Future<void> restoreTodo(TodoItem todo);
}

class FirestoreTodoRepository implements TodoRepository {
  FirestoreTodoRepository({
    required AuthService authService,
    FirebaseFirestore? firestore,
    Uuid uuid = const Uuid(),
  }) : _authService = authService,
       _db = firestore ?? FirebaseFirestore.instance,
       _uuid = uuid;

  final AuthService _authService;
  final FirebaseFirestore _db;
  final Uuid _uuid;

  @override
  Stream<List<TodoItem>> watchTodos() {
    return _authService.userStream.switchMap((user) {
      if (user == null) return Stream.value(const <TodoItem>[]);

      return _db
          .collection('users')
          .doc(user.uid)
          .collection('todos')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map(TodoItem.fromFirestore).toList(),
          );
    });
  }

  @override
  Future<void> addTodo(String title) async {
    final id = _uuid.v1();
    final now = DateTime.now();
    final todo = TodoItem(
      id: id,
      title: title.trim(),
      isCompleted: false,
      createdAt: now,
      updatedAt: now,
    );
    await _todosCollection().doc(id).set(todo.toFirestore());
  }

  @override
  Future<void> updateTitle(TodoItem todo, String title) {
    return _todosCollection().doc(todo.id).update({
      'title': title.trim(),
      'updatedAt': DateTime.now(),
    });
  }

  @override
  Future<void> setCompleted(TodoItem todo, bool isCompleted) {
    final now = DateTime.now();
    return _todosCollection().doc(todo.id).update({
      'isCompleted': isCompleted,
      'completedAt': isCompleted ? now : null,
      'updatedAt': now,
    });
  }

  @override
  Future<void> deleteTodo(TodoItem todo) {
    return _todosCollection().doc(todo.id).delete();
  }

  @override
  Future<void> restoreTodo(TodoItem todo) {
    return _todosCollection().doc(todo.id).set(todo.toFirestore());
  }

  CollectionReference<Map<String, dynamic>> _todosCollection() {
    final user = _authService.user;
    if (user == null) throw StateError('User is not logged in');
    return _db.collection('users').doc(user.uid).collection('todos');
  }
}
