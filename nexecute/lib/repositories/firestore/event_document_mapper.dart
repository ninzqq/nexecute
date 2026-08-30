import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/repositories/commands/create_event_command.dart';
import 'package:nexecute/repositories/firestore/schema/firestore_document_schema.dart';

abstract final class EventDocumentMapper {
  static final _schema = FirestoreDocumentSchema(
    migrations: {
      0: _migrateV0ToV1,
      1: _migrateV1ToV2,
      2: noOpFirestoreDocumentMigration,
    },
  );

  static Map<String, dynamic> toMap(Event event) => _schema.stamp({
    'id': event.id,
    'title': event.title,
    'description': event.description,
    'startTime': event.startTime,
    'endTime': event.endTime,
    'isAllDay': event.isAllDay,
    'tags': event.tags,
    'reminderMinutesBefore': event.reminder.minutesBefore,
  });

  static Map<String, dynamic> toCreateMap(CreateEventCommand command) => {
    ...toMap(command.toEvent()),
    'creationId': command.creationId,
    'sourceNoteId': command.sourceNoteId,
    'creationSource': 'aiNoteEventProposal',
    'createdAt': command.createdAt,
  };

  static Event fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    return fromMap(document.id, document.data() ?? const {});
  }

  static Event fromMap(String id, Map<String, dynamic> data) {
    final migrated = _schema.migrate(data);
    return Event(
      id: id,
      title: migrated['title']?.toString() ?? '',
      description: migrated['description']?.toString() ?? '',
      startTime: _requiredDate(migrated['startTime'], 'startTime'),
      endTime: _requiredDate(migrated['endTime'], 'endTime'),
      isAllDay: migrated['isAllDay'] == true,
      tags: _stringList(migrated['tags']),
      reminder: EventReminder.fromMinutesBefore(
        migrated['reminderMinutesBefore'],
      ),
    );
  }

  static void _migrateV0ToV1(Map<String, dynamic> document) {
    document.putIfAbsent('description', () => '');
    document.putIfAbsent('isAllDay', () => false);
    document.putIfAbsent('tags', () => <String>[]);
  }

  static void _migrateV1ToV2(Map<String, dynamic> document) {
    document.putIfAbsent('reminderMinutesBefore', () => null);
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
