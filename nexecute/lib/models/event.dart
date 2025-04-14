import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;

  const Event({
    required this.id,
    required this.title,
    this.description = '',
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
  });

  @override
  String toString() {
    return 'Event(id: $id, title: $title, description: $description, startTime: $startTime, endTime: $endTime, isAllDay: $isAllDay)';
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startTime': startTime,
      'endTime': endTime,
      'isAllDay': isAllDay,
    };
  }

  factory Event.fromFirestore(DocumentSnapshot doc) {
    return Event(
      id: doc.id,
      title: doc.get('title') ?? '',
      description: doc.get('description') ?? '',
      startTime: doc.get('startTime').toDate(),
      endTime: doc.get('endTime').toDate(),
      isAllDay: doc.get('isAllDay') ?? false,
    );
  }
}
