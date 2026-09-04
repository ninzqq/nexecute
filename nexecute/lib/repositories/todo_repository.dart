import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/todo_item.dart';
import 'package:nexecute/repositories/commands/create_todos_command.dart';
import 'package:nexecute/repositories/firestore/todo_document_mapper.dart';
import 'package:nexecute/repositories/firestore/schema/app_data_schema.dart';
import 'package:nexecute/services/auth.dart';
import 'package:nexecute/services/authenticated_data_stream.dart';
import 'package:nexecute/services/firestore_read_diagnostics.dart';
import 'package:uuid/uuid.dart';

export 'package:nexecute/repositories/commands/create_todos_command.dart';

abstract interface class TodoRepository {
  Stream<DataState<List<TodoItem>>> watchTodos();

  Future<void> addTodo(String title);

  Future<void> createTodos(CreateTodosCommand command);

  Future<void> updateTitle(TodoItem todo, String title);

  Future<void> setCompleted(TodoItem todo, bool isCompleted);

  Future<void> deleteTodo(TodoItem todo);

  Future<void> restoreTodo(TodoItem todo);
}

class FirestoreTodoRepository implements TodoRepository {
  FirestoreTodoRepository({
    required AuthService authService,
    FirebaseFirestore? firestore,
    FirestoreReadDiagnostics? readDiagnostics,
    Uuid uuid = const Uuid(),
  }) : _authService = authService,
       _db = firestore ?? FirebaseFirestore.instance,
       _readDiagnostics = readDiagnostics ?? FirestoreReadDiagnostics.disabled,
       _uuid = uuid;

  final AuthService _authService;
  final FirebaseFirestore _db;
  final FirestoreReadDiagnostics _readDiagnostics;
  final Uuid _uuid;

  @override
  Stream<DataState<List<TodoItem>>> watchTodos() {
    return authenticatedDataStream(
      authentication: _authService.userStream,
      isEmpty: (todos) => todos.isEmpty,
      load:
          (user) => _readDiagnostics
              .watchQuery(
                operation: 'todos.all',
                query: _db
                    .collection('users')
                    .doc(user.uid)
                    .collection('todos'),
              )
              .map(
                (snapshot) =>
                    snapshot.docs.map(TodoDocumentMapper.fromDocument).toList(),
              ),
    );
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
    await _todosCollection().doc(id).set(TodoDocumentMapper.toMap(todo));
  }

  @override
  Future<void> createTodos(CreateTodosCommand command) async {
    final todos = _todosCollection();
    final batch = _db.batch();

    for (var index = 0; index < command.titles.length; index++) {
      final todo = TodoItem(
        id: command.todoIdAt(index),
        title: command.titles[index],
        isCompleted: false,
        createdAt: command.createdAt,
        updatedAt: command.createdAt,
      );
      batch.set(todos.doc(todo.id), {
        ...TodoDocumentMapper.toMap(todo),
        'creationId': command.creationId,
        'sourceNoteId': command.sourceNoteId,
        'creationSource': 'aiNoteTaskProposal',
      });
    }

    await batch.commit();
  }

  @override
  Future<void> updateTitle(TodoItem todo, String title) {
    return _todosCollection()
        .doc(todo.id)
        .update(
          AppDataSchema.stamp({
            'title': title.trim(),
            'updatedAt': DateTime.now(),
          }),
        );
  }

  @override
  Future<void> setCompleted(TodoItem todo, bool isCompleted) {
    final now = DateTime.now();
    return _todosCollection()
        .doc(todo.id)
        .update(
          AppDataSchema.stamp({
            'isCompleted': isCompleted,
            'completedAt': isCompleted ? now : null,
            'updatedAt': now,
          }),
        );
  }

  @override
  Future<void> deleteTodo(TodoItem todo) {
    return _todosCollection().doc(todo.id).delete();
  }

  @override
  Future<void> restoreTodo(TodoItem todo) {
    return _todosCollection().doc(todo.id).set(TodoDocumentMapper.toMap(todo));
  }

  CollectionReference<Map<String, dynamic>> _todosCollection() {
    final user = _authService.user;
    if (user == null) throw StateError('User is not logged in');
    return _db.collection('users').doc(user.uid).collection('todos');
  }
}
