import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/models/todo_item.dart';

abstract final class TodoDocumentMapper {
  static Map<String, dynamic> toMap(TodoItem todo) => {
    'id': todo.id,
    'title': todo.title,
    'isCompleted': todo.isCompleted,
    'createdAt': todo.createdAt,
    'updatedAt': todo.updatedAt,
    'completedAt': todo.completedAt,
  };

  static TodoItem fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return fromMap(document.id, document.data() ?? const {});
  }

  static TodoItem fromMap(String id, Map<String, dynamic> data) {
    final createdAt = _date(data['createdAt']) ?? DateTime.now();
    return TodoItem(
      id: id,
      title: data['title']?.toString() ?? '',
      isCompleted: data['isCompleted'] == true,
      createdAt: createdAt,
      updatedAt: _date(data['updatedAt']) ?? createdAt,
      completedAt: _date(data['completedAt']),
    );
  }

  static DateTime? _date(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime date => date,
    _ => null,
  };
}
