import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/calendar/bottomsheets/event_details.dart';
import 'package:nexecute/home/widgets/quicxecs.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/tag.dart' as models;
import 'package:nexecute/models/todo_item.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/search/unified_search_page.dart';
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';

import 'support/fake_event_repository.dart';

void main() {
  testWidgets('searches events, tasks, notes, and tags from one screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final event = Event(
      id: 'event-1',
      title: 'Planning session',
      description: 'Prepare quarterly roadmap',
      startTime: DateTime(2026, 9, 1, 9),
      endTime: DateTime(2026, 9, 1, 10),
      tags: const ['Work'],
    );
    final repository = FakeEventRepository(events: [event]);
    final note = Quicxec(
      id: 'note-1',
      title: 'Work notes',
      text: '',
      created: DateTime(2026, 9, 1),
      tags: const ['Work'],
      contentType: NoteContentType.checklist,
      checklistItems: const [
        NoteChecklistItem(id: 'passport', text: 'Pack passport'),
      ],
    );
    final todo = TodoItem(
      id: 'todo-1',
      title: 'Write work report',
      isCompleted: false,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<EventRepository>.value(value: repository),
          Provider<DataState<List<Quicxec>>>.value(value: DataReady([note])),
          Provider<DataState<List<TodoItem>>>.value(value: DataReady([todo])),
          Provider<DataState<models.Tags>>.value(
            value: DataReady(models.Tags(tags: ['Work'])),
          ),
        ],
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: const UnifiedSearchPage(),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('unified-search-field')),
      'WORK',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(repository.searchedQueries, ['work']);
    expect(find.byKey(const ValueKey('search-event-event-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-todo-todo-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-note-note-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-tag-Work')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('search-event-event-1')));
    await tester.pumpAndSettle();

    expect(find.byType(EventDetailsBottomSheet), findsOneWidget);
  });

  testWidgets('finds checklist text while the Notes filter remains available', (
    tester,
  ) async {
    final matchingNote = Quicxec(
      id: 'note-1',
      title: 'Travel list',
      text: '',
      created: DateTime(2026, 9, 1),
      contentType: NoteContentType.checklist,
      checklistItems: const [
        NoteChecklistItem(id: 'passport', text: 'Pack passport'),
      ],
    );
    final otherNote = Quicxec(
      id: 'note-2',
      title: 'Groceries',
      text: 'Milk',
      created: DateTime(2026, 9, 1),
    );

    await tester.pumpWidget(
      Provider<DataState<List<Quicxec>>>.value(
        value: DataReady([matchingNote, otherNote]),
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: const Scaffold(body: Quicxecs()),
        ),
      ),
    );

    expect(find.text('Travel list'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'passport');
    await tester.pump();

    expect(find.text('Travel list'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);
  });
}
