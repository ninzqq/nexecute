import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/todo_item.dart';
import 'package:nexecute/search/search_matcher.dart';

void main() {
  test('matches every query term across event fields', () {
    final event = Event(
      id: 'event-1',
      title: 'Project planning',
      description: 'Prepare the launch',
      startTime: DateTime(2026, 9, 1, 9),
      endTime: DateTime(2026, 9, 1, 10),
      tags: const ['Work'],
    );

    expect(eventMatchesSearch(event, 'PLAN launch'), isTrue);
    expect(eventMatchesSearch(event, 'planning personal'), isFalse);
  });

  test('matches note checklist text and tags', () {
    final note = Quicxec(
      id: 'note-1',
      title: 'Travel',
      text: '',
      created: DateTime(2026, 9, 1),
      contentType: NoteContentType.checklist,
      checklistItems: const [
        NoteChecklistItem(id: 'passport', text: 'Pack passport'),
      ],
      tags: const ['Personal'],
    );

    expect(noteMatchesSearch(note, 'passport'), isTrue);
    expect(noteMatchesSearch(note, 'travel personal'), isTrue);
  });

  test('matches task titles and tag names case-insensitively', () {
    final todo = TodoItem(
      id: 'todo-1',
      title: 'Write work report',
      isCompleted: false,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    );

    expect(todoMatchesSearch(todo, 'WORK'), isTrue);
    expect(tagMatchesSearch('Deep Work', 'deep work'), isTrue);
    expect(tagMatchesSearch('Personal', 'work'), isFalse);
  });

  test('does not match an empty query', () {
    expect(matchesSearchQuery(['anything'], '   '), isFalse);
  });
}
