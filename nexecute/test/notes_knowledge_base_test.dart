import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/home/widgets/quicxecs.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/note_folder.dart';
import 'package:nexecute/models/notes_controller.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/repositories/note_folder_repository.dart';
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';

void main() {
  final folder = NoteFolder(
    id: 'projects',
    name: 'Projects',
    createdAt: DateTime(2026, 8, 28),
    updatedAt: DateTime(2026, 8, 28),
  );
  final notes = [
    Quicxec(
      id: 'quick',
      title: 'Quick thought',
      text: 'Inbox content',
      created: DateTime(2026, 8, 28, 9),
    ),
    Quicxec(
      id: 'project',
      title: 'Project reference',
      text: 'Structured content',
      folderId: folder.id,
      created: DateTime(2026, 8, 28, 10),
    ),
  ];

  testWidgets('browses Quick Notes, All Notes, and user folders', (
    tester,
  ) async {
    await _pumpKnowledgeBase(tester, notes: notes, folders: [folder]);

    expect(find.byKey(const Key('quick-notes-location')), findsOneWidget);
    expect(find.byKey(const Key('all-notes-location')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-folder-projects')), findsOneWidget);
    final folderBadge = tester.widget<Badge>(
      find.descendant(
        of: find.byKey(const ValueKey('note-folder-projects')),
        matching: find.byType(Badge),
      ),
    );
    expect(folderBadge.largeSize, 20);
    expect(folderBadge.padding, const EdgeInsets.symmetric(horizontal: 6));

    await tester.tap(find.byKey(const ValueKey('note-folder-projects')));
    await tester.pumpAndSettle();

    expect(find.text('Project reference'), findsOneWidget);
    expect(find.text('Quick thought'), findsNothing);

    await tester.enterText(find.byType(TextField), 'quick');
    await tester.pump();
    expect(find.text('Quick thought'), findsNothing);
    expect(find.text('No matching notes'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.byTooltip('Back to notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-notes-location')));
    await tester.pumpAndSettle();

    expect(find.text('Quick thought'), findsOneWidget);
    expect(find.text('Project reference'), findsNothing);
  });

  testWidgets('creates a folder from the knowledge-base root', (tester) async {
    final repository = _FakeNoteFolderRepository();
    await _pumpKnowledgeBase(
      tester,
      notes: notes,
      folders: [folder],
      repository: repository,
    );

    await tester.tap(find.byKey(const Key('create-note-folder')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note-folder-name-field')),
      'Research',
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(repository.addedName, 'Research');
  });
}

Future<void> _pumpKnowledgeBase(
  WidgetTester tester, {
  required List<Quicxec> notes,
  required List<NoteFolder> folders,
  NoteFolderRepository? repository,
}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<DataState<List<Quicxec>>>.value(value: DataReady(notes)),
        Provider<DataState<List<NoteFolder>>>.value(value: DataReady(folders)),
        ChangeNotifierProvider(create: (_) => NotesController()),
        Provider<NoteFolderRepository>.value(
          value: repository ?? _FakeNoteFolderRepository(),
        ),
      ],
      child: MaterialApp(
        theme: AppThemes.forPreset(AppThemePreset.midnight),
        home: const Scaffold(body: Quicxecs()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeNoteFolderRepository implements NoteFolderRepository {
  String? addedName;

  @override
  Future<void> addFolder(String name) async => addedName = name;

  @override
  Future<void> deleteFolder(String folderId) async {}

  @override
  Future<void> renameFolder(String folderId, String name) async {}

  @override
  Stream<DataState<List<NoteFolder>>> watchFolders() =>
      Stream.value(const DataEmpty([]));
}
