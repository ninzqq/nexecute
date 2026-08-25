import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/models/event.dart';

abstract final class EventDocumentMapper {
  static Map<String, dynamic> toMap(Event event) => {
    'id': event.id,
    'title': event.title,
    'description': event.description,
    'startTime': event.startTime,
    'endTime': event.endTime,
    'isAllDay': event.isAllDay,
    'tags': event.tags,
  };

  static Event fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    return fromMap(document.id, document.data() ?? const {});
  }

  static Event fromMap(String id, Map<String, dynamic> data) {
    return Event(
      id: id,
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      startTime: _requiredDate(data['startTime'], 'startTime'),
      endTime: _requiredDate(data['endTime'], 'endTime'),
      isAllDay: data['isAllDay'] == true,
      tags: _stringList(data['tags']),
    );
  }

  static DateTime _requiredDate(Object? value, String field) {
    final date = _date(value);
    if (date != null) return date;
    throw FormatException('Event is missing a valid $field');
  }

  static DateTime? _date(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime date => date,
    _ => null,
  };

  static List<String> _stringList(Object? value) =>
      value is List ? value.map((item) => item.toString()).toList() : const [];
}
