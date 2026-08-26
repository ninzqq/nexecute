import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/repositories/firestore/event_document_mapper.dart';
import 'package:nexecute/repositories/firestore/schema/app_data_schema.dart';
import 'package:test/test.dart';

void main() {
  test('maps Firestore-compatible event data into a domain event', () {
    final start = DateTime.utc(2026, 8, 25, 9);
    final end = DateTime.utc(2026, 8, 25, 10);

    final event = EventDocumentMapper.fromMap('event-1', {
      'title': 'Planning',
      'description': 'Prepare the release',
      'startTime': Timestamp.fromDate(start),
      'endTime': Timestamp.fromDate(end),
      'isAllDay': false,
      'tags': ['work'],
    });

    expect(event.id, 'event-1');
    expect(event.title, 'Planning');
    expect(event.startTime.toUtc(), start);
    expect(event.endTime.toUtc(), end);
    expect(event.tags, ['work']);
  });

  test(
    'maps a domain event without adding Firestore behavior to the model',
    () {
      final event = Event(
        id: 'event-2',
        title: 'Review',
        startTime: DateTime.utc(2026, 8, 26, 14),
        endTime: DateTime.utc(2026, 8, 26, 15),
        reminder: EventReminder.thirtyMinutesBefore,
      );

      final data = EventDocumentMapper.toMap(event);

      expect(data['id'], 'event-2');
      expect(data['title'], 'Review');
      expect(data['tags'], isEmpty);
      expect(data['reminderMinutesBefore'], 30);
      expect(data[AppDataSchema.versionField], AppDataSchema.currentVersion);
    },
  );

  test('migrates a version zero event before mapping it', () {
    final event = EventDocumentMapper.fromMap('legacy-event', {
      'title': 'Legacy',
      'startTime': DateTime.utc(2026, 8, 26, 14),
      'endTime': DateTime.utc(2026, 8, 26, 15),
    });

    expect(event.description, isEmpty);
    expect(event.isAllDay, isFalse);
    expect(event.tags, isEmpty);
    expect(event.reminder, EventReminder.none);
  });

  test('migrates a version one event to the reminder schema', () {
    final event = EventDocumentMapper.fromMap('version-one-event', {
      AppDataSchema.versionField: 1,
      'title': 'Before reminders',
      'startTime': DateTime.utc(2026, 8, 26, 14),
      'endTime': DateTime.utc(2026, 8, 26, 15),
    });

    expect(event.reminder, EventReminder.none);
  });
}
