import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final List<String> tags;

  const Event({
    required this.id,
    required this.title,
    this.description = '',
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
    this.tags = const [],
  });

  @override
  String toString() {
    return 'Event(id: $id, title: $title, description: $description, startTime: $startTime, endTime: $endTime, isAllDay: $isAllDay, tags: $tags)';
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startTime': startTime,
      'endTime': endTime,
      'isAllDay': isAllDay,
      'tags': tags,
    };
  }

  factory Event.fromFirestore(DocumentSnapshot doc) {
    List<String> tags = [];
    try {
      tags = doc.get('tags');
    } catch (e) {
      // If tags field is missing, return an empty list
      tags = [];
    }
    tags = List<String>.from(tags.map((item) => item.toString()));

    return Event(
      id: doc.id,
      title: doc.get('title') ?? '',
      description: doc.get('description') ?? '',
      startTime: doc.get('startTime').toDate(),
      endTime: doc.get('endTime').toDate(),
      isAllDay: doc.get('isAllDay') ?? false,
      tags: tags,
    );
  }
}
