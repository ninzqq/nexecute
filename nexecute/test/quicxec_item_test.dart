import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/home/widgets/quicxecitem.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/note_folder.dart';
import 'package:nexecute/models/todo_item.dart';
import 'package:nexecute/repositories/todo_repository.dart';
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';

import 'support/fake_ai_dependencies.dart';

void main() {
  testWidgets('long-pressing a note opens its action sheet', (tester) async {
    final note = Quicxec(
      id: 'note-1',
      title: 'Meeting notes',
      text: 'Discuss the next release',
      created: DateTime(2026, 8, 24, 9),
    );

    await tester.pumpWidget(
      Provider<DataState<List<NoteFolder>>>.value(
        value: const DataEmpty([]),
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 120,
              child: QuicxecItem(quicxec: note),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.byType(QuicxecItem));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Meeting notes'), findsWidgets);
    expect(find.text('Note actions'), findsOneWidget);
    expect(find.text('Propose event with AI'), findsOneWidget);
    expect(find.text('Propose tasks with AI'), findsOneWidget);
    expect(find.text('Move to folder'), findsOneWidget);
    expect(find.text('Quick Notes'), findsOneWidget);
    expect(find.text('Move note to trash'), findsOneWidget);
    expect(find.text('You can restore it later from Trash'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
  });

  testWidgets('trashed notes show restore and permanent-delete actions', (
    tester,
  ) async {
    final note = Quicxec(
      id: 'note-2',
      title: 'Archived idea',
      text: 'An older thought',
      trashed: true,
      created: DateTime(2026, 8, 24, 9),
    );

    await tester.pumpWidget(
      Provider<DataState<List<NoteFolder>>>.value(
        value: const DataEmpty([]),
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.neutral),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 120,
              child: QuicxecItem(quicxec: note),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.byType(QuicxecItem));
    await tester.pumpAndSettle();

    expect(find.text('Restore note'), findsOneWidget);
    expect(find.text('Delete permanently'), findsOneWidget);
    expect(find.text('Propose event with AI'), findsNothing);
    expect(find.text('Propose tasks with AI'), findsNothing);
    expect(find.text('This action cannot be undone'), findsOneWidget);
    expect(find.byIcon(Icons.restore_from_trash_rounded), findsOneWidget);
    expect(find.byIcon(Icons.delete_forever_rounded), findsOneWidget);
  });

  testWidgets('checklist notes show interactive checklist previews', (
    tester,
  ) async {
    final note = Quicxec(
      id: 'note-3',
      title: 'Packing list',
      text: 'Passport\nCharger',
      created: DateTime(2026, 8, 24, 9),
      contentType: NoteContentType.checklist,
      checklistItems: const [
        NoteChecklistItem(id: 'passport', text: 'Passport', isChecked: true),
        NoteChecklistItem(id: 'charger', text: 'Charger'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemes.forPreset(AppThemePreset.cyberpunk),
        home: Scaffold(
          body: SizedBox(width: 240, child: QuicxecItem(quicxec: note)),
        ),
      ),
    );

    expect(find.byKey(const Key('note-checklist-preview')), findsOneWidget);
    expect(find.text('Passport'), findsOneWidget);
    expect(find.text('Charger'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates confirmed AI tasks without changing the source note', (
    tester,
  ) async {
    final note = Quicxec(
      id: 'note-ai',
      title: 'Weekend plan',
      text: 'Buy coffee and call Sam.',
      created: DateTime.utc(2026, 8, 29),
    );
    final profile = AiConnectionProfile(
      id: 'home',
      name: 'Home AI',
      protocol: AiProtocol.openAiCompatibleChat,
      baseUrl: Uri.parse('https://ai.example.test/v1'),
      modelId: 'local-model',
    );
    final profileStore = FakeAiConnectionProfileStore(
      profiles: [profile],
      activeProfileId: profile.id,
    );
    final assistantRepository = FakeAiAssistantRepository(
      responseEvents: const [
        AiTextDelta(
          '{"schemaVersion":1,"tasks":[{"title":"Buy coffee"},{"title":"Call Sam"}]}',
        ),
        AiResponseCompleted(),
      ],
    );
    final todoRepository = _FakeTodoRepository();
    addTearDown(profileStore.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DataState<List<NoteFolder>>>.value(
            value: const DataEmpty([]),
          ),
          Provider<AiAssistantRepository>.value(value: assistantRepository),
          Provider<AiConnectionProfileStore>.value(value: profileStore),
          Provider<TodoRepository>.value(value: todoRepository),
        ],
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 120,
              child: QuicxecItem(quicxec: note),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.byType(QuicxecItem));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Propose tasks with AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-note-task-send')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ai-note-task-create')));
    await tester.tap(find.byKey(const Key('ai-note-task-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-note-task-confirm-create')));
    await tester.pumpAndSettle();

    expect(todoRepository.createdCommands, hasLength(1));
    expect(todoRepository.createdCommands.single.sourceNoteId, note.id);
    expect(todoRepository.createdCommands.single.titles, [
      'Buy coffee',
      'Call Sam',
    ]);
    expect(note.title, 'Weekend plan');
    expect(note.text, 'Buy coffee and call Sam.');

    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();
    expect(find.text('2 tasks created'), findsOneWidget);
    expect(assistantRepository.startedRequests, hasLength(1));
  });
}

class _FakeTodoRepository implements TodoRepository {
  final createdCommands = <CreateTodosCommand>[];

  @override
  Stream<DataState<List<TodoItem>>> watchTodos() =>
      Stream.value(const DataEmpty([]));

  @override
  Future<void> addTodo(String title) async {}

  @override
  Future<void> createTodos(CreateTodosCommand command) async {
    createdCommands.add(command);
  }

  @override
  Future<void> updateTitle(TodoItem todo, String title) async {}

  @override
  Future<void> setCompleted(TodoItem todo, bool isCompleted) async {}

  @override
  Future<void> deleteTodo(TodoItem todo) async {}

  @override
  Future<void> restoreTodo(TodoItem todo) async {}
}
