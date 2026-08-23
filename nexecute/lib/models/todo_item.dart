import 'package:cloud_firestore/cloud_firestore.dart';

class TodoItem {
  const TodoItem({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  final String id;
  final String title;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'completedAt': completedAt,
  };

  factory TodoItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      TodoItem.fromMap(doc.id, doc.data() ?? const {});

  factory TodoItem.fromMap(String id, Map<String, dynamic> data) {
    final createdAt = _readDate(data['createdAt']) ?? DateTime.now();
    return TodoItem(
      id: id,
      title: data['title'] as String? ?? '',
      isCompleted: data['isCompleted'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt: _readDate(data['updatedAt']) ?? createdAt,
      completedAt: _readDate(data['completedAt']),
    );
  }

  TodoItem copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) => TodoItem(
    id: id ?? this.id,
    title: title ?? this.title,
    isCompleted: isCompleted ?? this.isCompleted,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
  );

  static DateTime? _readDate(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime date => date,
    _ => null,
  };
}
