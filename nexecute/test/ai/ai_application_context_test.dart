import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/todo_item.dart';

void main() {
  test('maps application models to an explicit minimal context envelope', () {
    final range = CalendarQueryRange(
      startInclusive: DateTime.utc(2026, 9, 1),
      endExclusive: DateTime.utc(2026, 9, 2),
    );
    final envelope = AiApplicationContextBuilder.build(
      generatedAt: DateTime.utc(2026, 8, 29, 12),
      includeActiveTasks: true,
      tasks: [
        _todo(id: 'todo-secret-id', title: 'Buy oat milk'),
        _todo(
          id: 'completed-secret-id',
          title: 'Already done',
          isCompleted: true,
        ),
      ],
      eventRange: range,
      events: [
        Event(
          id: 'event-secret-id',
          title: 'Dentist',
          description: 'Bring the referral.',
          startTime: DateTime.utc(2026, 9, 1, 10),
          endTime: DateTime.utc(2026, 9, 1, 11),
          tags: const ['private-event-tag'],
        ),
        Event(
          id: 'outside-secret-id',
          title: 'Outside range',
          startTime: DateTime.utc(2026, 9, 3, 10),
          endTime: DateTime.utc(2026, 9, 3, 11),
        ),
      ],
      selectedNotes: [
        Quicxec(
          id: 'note-secret-id',
          title: 'Packing list',
          text: 'Pack a charger.',
          tags: const ['private-note-tag'],
          folderId: 'private-folder-id',
          created: DateTime.utc(2020),
        ),
      ],
    );

    final json = envelope.toJson();
    expect(json['schemaVersion'], aiApplicationContextSchemaVersion);
    expect(json['dataClassification'], aiApplicationContextDataClassification);
    expect(json['generatedAt'], '2026-08-29T12:00:00.000Z');
    expect(json['payloadTruncated'], isFalse);

    final attachments = json['attachments'] as List;
    expect(attachments.map((value) => (value as Map)['type']), [
      'selectedNotes',
      'activeTasks',
      'events',
    ]);
    final note = ((attachments[0] as Map)['items'] as List).single as Map;
    expect(note.keys, {
      'title',
      'titleTruncated',
      'contentType',
      'content',
      'contentTruncated',
    });
    final task = ((attachments[1] as Map)['items'] as List).single as Map;
    expect(task, {
      'title': 'Buy oat milk',
      'isCompleted': false,
      'titleTruncated': false,
    });
    final event = ((attachments[2] as Map)['items'] as List).single as Map;
    expect(event.keys, {
      'title',
      'titleTruncated',
      'startTime',
      'endTime',
      'isAllDay',
      'description',
      'descriptionTruncated',
    });
    expect(event['startTime'], '2026-09-01T10:00:00.000Z');

    final encoded = envelope.encode();
    for (final excluded in const [
      'todo-secret-id',
      'completed-secret-id',
      'event-secret-id',
      'outside-secret-id',
      'note-secret-id',
      'private-event-tag',
      'private-note-tag',
      'private-folder-id',
      'reminder',
    ]) {
      expect(encoded, isNot(contains(excluded)));
    }
  });

  test('caps note count, per-note content, and total note content', () {
    final notes = [
      for (var index = 0; index < 4; index++)
        Quicxec(
          id: 'note-$index',
          title: 'Note $index',
          text: List.filled(5000, '$index').join(),
          created: DateTime.utc(2026),
        ),
    ];

    final envelope = AiApplicationContextBuilder.build(
      generatedAt: DateTime.utc(2026),
      selectedNotes: notes,
    );
    final attachment =
        envelope.attachments.single as AiSelectedNotesContextAttachment;

    expect(attachment.notes, hasLength(3));
    expect(attachment.omittedCount, 1);
    expect(
      attachment.notes.map((note) => note.content!.length),
      everyElement(AiApplicationContextLimits.maxNoteContentCharacters),
    );
    expect(
      attachment.notes.fold(0, (total, note) => total + note.content!.length),
      AiApplicationContextLimits.maxTotalNoteContentCharacters,
    );
    expect(
      attachment.notes.map((note) => note.contentTruncated),
      everyElement(isTrue),
    );
  });

  test('caps checklist items and exposes all truncation', () {
    final note = Quicxec(
      id: 'checklist',
      title: List.filled(400, 'T').join(),
      text: '',
      created: DateTime.utc(2026),
      contentType: NoteContentType.checklist,
      checklistItems: [
        for (var index = 0; index < 60; index++)
          NoteChecklistItem(
            id: 'item-$index',
            text: List.filled(600, '${index % 10}').join(),
            isChecked: index.isEven,
          ),
      ],
    );

    final envelope = AiApplicationContextBuilder.build(
      generatedAt: DateTime.utc(2026),
      selectedNotes: [note],
    );
    final mapped =
        (envelope.attachments.single as AiSelectedNotesContextAttachment)
            .notes
            .single;

    expect(mapped.title.length, AiApplicationContextLimits.maxTitleCharacters);
    expect(mapped.titleTruncated, isTrue);
    expect(mapped.contentType, AiContextNoteContentType.checklist);
    expect(mapped.content, isNull);
    expect(mapped.checklistItems, hasLength(8));
    expect(mapped.omittedChecklistItemCount, 52);
    expect(
      mapped.checklistItems.fold(0, (sum, item) => sum + item.text.length),
      AiApplicationContextLimits.maxNoteContentCharacters,
    );
    expect(
      mapped.checklistItems.map((item) => item.textTruncated),
      everyElement(isTrue),
    );
  });

  test('caps active tasks and reports omitted records', () {
    final envelope = AiApplicationContextBuilder.build(
      generatedAt: DateTime.utc(2026),
      includeActiveTasks: true,
      tasks: [
        for (var index = 0; index < 60; index++)
          _todo(id: '$index', title: 'Task $index'),
        _todo(id: 'done', title: 'Done', isCompleted: true),
      ],
    );
    final attachment =
        envelope.attachments.single as AiActiveTasksContextAttachment;

    expect(attachment.tasks, hasLength(50));
    expect(attachment.omittedCount, 10);
    expect(attachment.tasks.every((task) => !task.isCompleted), isTrue);
  });

  test('caps, filters, and sorts events inside the authorized range', () {
    final range = CalendarQueryRange(
      startInclusive: DateTime.utc(2026, 9, 1),
      endExclusive: DateTime.utc(2026, 9, 3),
    );
    final events = [
      for (var index = 0; index < 105; index++)
        Event(
          id: '$index',
          title: 'Event $index',
          startTime: DateTime.utc(2026, 9, 1, 23, 59 - (index % 59)),
          endTime: DateTime.utc(2026, 9, 2),
        ),
      Event(
        id: 'outside',
        title: 'Outside',
        startTime: DateTime.utc(2026, 9, 4),
        endTime: DateTime.utc(2026, 9, 4, 1),
      ),
    ];

    final envelope = AiApplicationContextBuilder.build(
      generatedAt: DateTime.utc(2026),
      eventRange: range,
      events: events,
    );
    final attachment = envelope.attachments.single as AiEventsContextAttachment;

    expect(attachment.events, hasLength(100));
    expect(attachment.omittedCount, 5);
    for (var index = 1; index < attachment.events.length; index++) {
      expect(
        attachment.events[index].startTime.isBefore(
          attachment.events[index - 1].startTime,
        ),
        isFalse,
      );
    }
  });

  test('rejects event ranges beyond the calendar-day limit', () {
    expect(
      () => AiApplicationContextBuilder.build(
        generatedAt: DateTime.utc(2026),
        eventRange: CalendarQueryRange(
          startInclusive: DateTime(2026, 1, 1),
          endExclusive: DateTime(2026, 2, 2),
        ),
      ),
      throwsArgumentError,
    );
  });

  test(
    'enforces the final serialized payload budget with visible omissions',
    () {
      final range = CalendarQueryRange(
        startInclusive: DateTime.utc(2026, 9, 1),
        endExclusive: DateTime.utc(2026, 9, 2),
      );
      final envelope = AiApplicationContextBuilder.build(
        generatedAt: DateTime.utc(2026),
        includeActiveTasks: true,
        tasks: [
          for (var index = 0; index < 50; index++)
            _todo(
              id: '$index',
              title: List.filled(200, '${index % 10}').join(),
            ),
        ],
        eventRange: range,
        events: [
          for (var index = 0; index < 100; index++)
            Event(
              id: '$index',
              title: List.filled(300, 'E').join(),
              description: List.filled(500, 'D').join(),
              startTime: DateTime.utc(2026, 9, 1, 10),
              endTime: DateTime.utc(2026, 9, 1, 11),
            ),
        ],
        selectedNotes: [
          for (var index = 0; index < 3; index++)
            Quicxec(
              id: '$index',
              title: 'Note $index',
              text: List.filled(4000, 'N').join(),
              created: DateTime.utc(2026),
            ),
        ],
      );

      expect(
        envelope.serializedCharacterCount,
        lessThanOrEqualTo(AiApplicationContextLimits.maxPayloadCharacters),
      );
      expect(envelope.payloadTruncated, isTrue);
      final notes =
          envelope.attachments
              .whereType<AiSelectedNotesContextAttachment>()
              .single;
      final tasks =
          envelope.attachments
              .whereType<AiActiveTasksContextAttachment>()
              .single;
      final events =
          envelope.attachments.whereType<AiEventsContextAttachment>().single;
      expect(notes.notes, hasLength(3));
      expect(tasks.omittedCount + events.omittedCount, greaterThan(0));
    },
  );

  test('context collections are immutable snapshots', () {
    final source = [const AiTaskContextItem(title: 'Task', isCompleted: false)];
    final attachment = AiActiveTasksContextAttachment(
      tasks: source,
      omittedCount: 0,
    );
    final envelope = AiApplicationContextEnvelope(
      generatedAt: DateTime.utc(2026),
      attachments: [attachment],
    );

    source.clear();
    expect(attachment.tasks, hasLength(1));
    expect(() => attachment.tasks.clear(), throwsUnsupportedError);
    expect(() => envelope.attachments.clear(), throwsUnsupportedError);
  });
}

TodoItem _todo({
  required String id,
  required String title,
  bool isCompleted = false,
}) => TodoItem(
  id: id,
  title: title,
  isCompleted: isCompleted,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
