import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/models/todo_item.dart';
import 'package:nexecute/repositories/firestore/schema/firestore_document_schema.dart';

abstract final class TodoDocumentMapper {
  static final _schema = FirestoreDocumentSchema(
    migrations: {0: _migrateV0ToV1, 1: noOpFirestoreDocumentMigration},
  );

  static Map<String, dynamic> toMap(TodoItem todo) => _schema.stamp({
    'id': todo.id,
    'title': todo.title,
    'isCompleted': todo.isCompleted,
    'createdAt': todo.createdAt,
    'updatedAt': todo.updatedAt,
    'completedAt': todo.completedAt,
  });

  static TodoItem fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return fromMap(document.id, document.data() ?? const {});
  }

  static TodoItem fromMap(String id, Map<String, dynamic> data) {
    final migrated = _schema.migrate(data);
    final createdAt = _date(migrated['createdAt']) ?? DateTime.now();
    return TodoItem(
      id: id,
      title: migrated['title']?.toString() ?? '',
      isCompleted: migrated['isCompleted'] == true,
      createdAt: createdAt,
      updatedAt: _date(migrated['updatedAt']) ?? createdAt,
      completedAt: _date(migrated['completedAt']),
    );
  }

  static void _migrateV0ToV1(Map<String, dynamic> document) {
    document.putIfAbsent('title', () => '');
    document.putIfAbsent('isCompleted', () => false);
    document.putIfAbsent('completedAt', () => null);
  }

  static DateTime? _date(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime date => date,
    _ => null,
  };
}
