import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/home/bottomsheets/item_editor_sheet.dart';
import 'package:nexecute/home/bottomsheets/item_editor_header.dart';
import 'package:nexecute/home/widgets/quicxecitem.dart';
import 'package:nexecute/home/widgets/quicxecs.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/tag.dart' as models;
import 'package:nexecute/repositories/note_repository.dart';
import 'package:nexecute/models/note_folder.dart';
import 'package:nexecute/models/notes_controller.dart';
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('notes use a two-column masonry layout with variable heights', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(_notesApp(_notes));
    await tester.pumpAndSettle();

    expect(find.byType(MasonryGridView), findsOneWidget);

    final shortCard = find.ancestor(
      of: find.text('Short note'),
      matching: find.byType(Card),
    );
    final longCard = find.ancestor(
      of: find.text('Long note'),
      matching: find.byType(Card),
    );

    expect(tester.getTopLeft(shortCard).dy, tester.getTopLeft(longCard).dy);
    expect(
      tester.getTopLeft(shortCard).dx,
      isNot(tester.getTopLeft(longCard).dx),
    );
    expect(
      tester.getSize(longCard).height,
      greaterThan(tester.getSize(shortCard).height),
    );
    expect(tester.widget<Text>(find.text('Short note')).style?.fontSize, 15);
    expect(tester.widget<Text>(find.text('One line')).style?.fontSize, 14);
    expect(tester.widget<Text>(find.text(_notes[1].text)).maxLines, 6);
  });

  testWidgets('notes derive desktop column counts from the shared layout', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(_notesApp(_notes));
    await tester.pumpAndSettle();
    expect(_columnCount(tester), 2);

    tester.view.physicalSize = const Size(700, 900);
    await tester.pumpAndSettle();
    expect(_columnCount(tester), 3);

    tester.view.physicalSize = const Size(1000, 900);
    await tester.pumpAndSettle();
    expect(_columnCount(tester), 4);
    expect(find.byKey(const Key('notes-preview-pane')), findsNothing);

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();
    expect(_columnCount(tester), 3);
    expect(find.byKey(const Key('notes-preview-pane')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('notes-preview-pane'))).width,
      400,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide notes preview stays open while selecting another tile', (
    tester,
  ) async {
    final controller = NotesController()..openAllNotes();
    addTearDown(controller.dispose);
    _setViewport(tester, const Size(1200, 900));
    await tester.pumpWidget(_notesApp(_notes, controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Select a note to preview'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(QuicxecItem),
        matching: find.text('Long note'),
      ),
    );
    await tester.pumpAndSettle();

    final preview = find.byKey(const Key('selected-note-preview'));
    expect(preview, findsOneWidget);
    expect(
      find.descendant(of: preview, matching: find.text('Long note')),
      findsOneWidget,
    );
    expect(controller.selectedNoteId, 'long-note');
    expect(
      tester.widget<QuicxecItem>(find.byType(QuicxecItem).first).selected,
      isTrue,
    );
    expect(find.byKey(const Key('desktop-item-editor-dialog')), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(QuicxecItem),
        matching: find.text('Short note'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: preview, matching: find.text('Short note')),
      findsOneWidget,
    );
    expect(controller.selectedNoteId, 'short-note');
    expect(find.byKey(const Key('notes-masonry-grid')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide preview shows complete checklist, folder, and tags', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 900));
    final folder = NoteFolder(
      id: 'projects',
      name: 'Projects',
      createdAt: DateTime(2026, 8, 24),
      updatedAt: DateTime(2026, 8, 24),
    );
    final note = Quicxec(
      id: 'checklist',
      title: 'Packing list',
      text: 'Passport\nCharger',
      created: DateTime(2026, 8, 24),
      folderId: folder.id,
      tags: const ['travel'],
      contentType: NoteContentType.checklist,
      checklistItems: const [
        NoteChecklistItem(id: 'passport', text: 'Passport', isChecked: true),
        NoteChecklistItem(id: 'charger', text: 'Charger'),
      ],
    );
    final controller = NotesController()..openAllNotes();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _notesApp([note], folders: [folder], controller: controller),
    );
    await tester.pumpAndSettle();

    controller.selectNote(note.id);
    await tester.pumpAndSettle();
    final preview = find.byKey(const Key('selected-note-preview'));
    expect(
      find.descendant(of: preview, matching: find.text('Projects')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: preview, matching: find.text('Passport')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: preview, matching: find.text('Charger')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: preview, matching: find.text('travel')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: preview,
        matching: find.byIcon(Icons.check_box_rounded),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide note edits save in the pane and return to preview', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 900));
    final controller = NotesController()..openAllNotes();
    final repository = _FakeNoteRepository();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _notesApp(_notes, controller: controller, repository: repository),
    );
    await tester.pumpAndSettle();

    controller.selectNote('long-note');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit note'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('inline-note-editor')), findsOneWidget);
    expect(find.byType(ItemEditorSheet), findsOneWidget);
    expect(find.byKey(const Key('desktop-item-editor-dialog')), findsNothing);
    final editor = tester.getRect(find.byKey(const Key('inline-note-editor')));
    final header = tester.getRect(find.byType(ItemEditorHeader));
    final format = tester.getRect(
      find.byKey(const Key('note-format-selector')),
    );
    final description = tester.getRect(
      find.byKey(const Key('note-description-field')),
    );
    expect(header.height, lessThanOrEqualTo(48));
    expect(format.height, lessThanOrEqualTo(40));
    expect(find.text('Note format'), findsNothing);
    expect(description.top - editor.top, lessThan(200));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Updated note',
    );
    await tester.tap(find.byKey(const Key('item-editor-submit-button')));
    await tester.pumpAndSettle();

    expect(repository.updatedNote?.noteId, 'long-note');
    expect(repository.updatedNote?.title, 'Updated note');
    expect(find.byKey(const Key('inline-note-editor')), findsNothing);
    expect(find.byKey(const Key('selected-note-preview')), findsOneWidget);
    expect(controller.selectedNoteId, 'long-note');
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching notes protects unsaved inline edits', (tester) async {
    _setViewport(tester, const Size(1200, 900));
    final controller = NotesController()..openAllNotes();
    final repository = _FakeNoteRepository();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _notesApp(_notes, controller: controller, repository: repository),
    );
    await tester.pumpAndSettle();

    controller.selectNote('long-note');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Draft change',
    );

    Future<void> selectShortNote() async {
      await tester.tap(
        find.descendant(
          of: find.byType(QuicxecItem),
          matching: find.text('Short note'),
        ),
      );
      await tester.pumpAndSettle();
    }

    await selectShortNote();
    expect(find.text('Save changes to this note?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(controller.selectedNoteId, 'long-note');
    expect(find.byKey(const Key('inline-note-editor')), findsOneWidget);

    await selectShortNote();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(controller.selectedNoteId, 'short-note');
    expect(repository.updatedNote, isNull);

    controller.selectNote('long-note');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Saved change',
    );
    await selectShortNote();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Save'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.updatedNote?.title, 'Saved change');
    expect(controller.selectedNoteId, 'short-note');
    expect(find.byKey(const Key('inline-note-editor')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new notes save directly from the wide pane', (tester) async {
    _setViewport(tester, const Size(1200, 900));
    final controller = NotesController()..openAllNotes();
    final repository = _FakeNoteRepository();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _notesApp(_notes, controller: controller, repository: repository),
    );
    await tester.pumpAndSettle();

    await controller.requestOpenNewNote();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inline-note-editor')), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Fresh idea',
    );
    await tester.enterText(
      find.byKey(const Key('note-description-field')),
      'A note from the pane',
    );
    await tester.tap(find.byKey(const Key('item-editor-submit-button')));
    await tester.pumpAndSettle();

    expect(repository.addedNote?.title, 'Fresh idea');
    expect(repository.addedNote?.text, 'A note from the pane');
    expect(controller.isCreatingNote, isFalse);
    expect(find.byKey(const Key('inline-note-editor')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling a dirty new note offers a discard choice', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 900));
    final controller = NotesController()..openAllNotes();
    final repository = _FakeNoteRepository();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _notesApp(_notes, controller: controller, repository: repository),
    );
    await tester.pumpAndSettle();

    await controller.requestOpenNewNote();
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Unsaved idea',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Save changes to this note?'), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inline-note-editor')), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inline-note-editor')), findsNothing);
    expect(controller.isCreatingNote, isFalse);
    expect(repository.addedNote, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('archiving from the inline editor closes the note pane', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 900));
    final controller = NotesController()..openAllNotes();
    final repository = _FakeNoteRepository();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _notesApp(_notes, controller: controller, repository: repository),
    );
    await tester.pumpAndSettle();

    controller.selectNote('long-note');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit note'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Archive note'));
    await tester.pumpAndSettle();

    expect(repository.archivedNote?.id, 'long-note');
    expect(controller.selectedNoteId, isNull);
    expect(find.byKey(const Key('inline-note-editor')), findsNothing);
    expect(find.text('Select a note to preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection clears when a note leaves the current view', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 900));
    final controller = NotesController()..openAllNotes();
    final notes = ValueNotifier<List<Quicxec>>([..._notes]);
    addTearDown(controller.dispose);
    addTearDown(notes.dispose);
    await tester.pumpWidget(
      _notesApp(_notes, controller: controller, notesListenable: notes),
    );
    await tester.pumpAndSettle();

    controller.selectNote('long-note');
    await tester.pumpAndSettle();
    notes.value = [_notes.first];
    await tester.pumpAndSettle();

    expect(controller.selectedNoteId, isNull);
    expect(find.byKey(const Key('selected-note-preview')), findsNothing);
    expect(find.text('Select a note to preview'), findsOneWidget);

    controller.selectNote('short-note');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search notes'),
      'no matching note',
    );
    await tester.pumpAndSettle();
    expect(controller.selectedNoteId, isNull);
    expect(find.text('No matching notes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a dirty note survives filtering and a live resize', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 900));
    final controller = NotesController()..openAllNotes();
    final repository = _FakeNoteRepository();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _notesApp(_notes, controller: controller, repository: repository),
    );
    await tester.pumpAndSettle();

    controller.selectNote('long-note');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Resizing draft',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Search notes'),
      'short',
    );
    await tester.pumpAndSettle();
    expect(controller.selectedNoteId, 'long-note');
    expect(find.byKey(const Key('inline-note-editor')), findsOneWidget);

    tester.view.physicalSize = const Size(1000, 900);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notes-preview-pane')), findsNothing);
    expect(find.byKey(const Key('inline-note-editor')), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Title'), findsOneWidget);
    expect(find.text('Resizing draft'), findsOneWidget);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inline-note-editor')), findsOneWidget);
    expect(find.text('Resizing draft'), findsOneWidget);

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inline-note-editor')), findsOneWidget);
    expect(find.text('Resizing draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an external archive preserves an unsaved note draft', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 900));
    final controller = NotesController()..openAllNotes();
    final notes = ValueNotifier<List<Quicxec>>([..._notes]);
    addTearDown(controller.dispose);
    addTearDown(notes.dispose);
    await tester.pumpWidget(
      _notesApp(_notes, controller: controller, notesListenable: notes),
    );
    await tester.pumpAndSettle();

    controller.selectNote('long-note');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Unsaved archive draft',
    );
    notes.value = [_notes.first];
    await tester.pumpAndSettle();

    expect(controller.selectedNoteId, 'long-note');
    expect(find.byKey(const Key('inline-note-editor')), findsOneWidget);
    expect(find.text('Unsaved archive draft'), findsOneWidget);
    expect(find.textContaining('Your draft is preserved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a moved note clears selection in its old folder', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 900));
    final folder = NoteFolder(
      id: 'projects',
      name: 'Projects',
      createdAt: DateTime(2026, 8, 24),
      updatedAt: DateTime(2026, 8, 24),
    );
    final note = Quicxec(
      id: 'project-note',
      title: 'Project note',
      text: 'Reference',
      created: DateTime(2026, 8, 24),
      folderId: folder.id,
    );
    final controller = NotesController()..openFolder(folder.id);
    final notes = ValueNotifier<List<Quicxec>>([note]);
    addTearDown(controller.dispose);
    addTearDown(notes.dispose);
    await tester.pumpWidget(
      _notesApp(
        [note],
        folders: [folder],
        controller: controller,
        notesListenable: notes,
      ),
    );
    await tester.pumpAndSettle();

    controller.selectNote(note.id);
    await tester.pumpAndSettle();
    notes.value = [
      Quicxec(
        id: note.id,
        title: note.title,
        text: note.text,
        created: note.created,
      ),
    ];
    await tester.pumpAndSettle();

    expect(controller.selectedNoteId, isNull);
    expect(find.text('Select a note to preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('remote changes refresh a pristine editor and warn on conflict', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 900));
    final controller = NotesController()..openAllNotes();
    final notes = ValueNotifier<List<Quicxec>>([..._notes]);
    addTearDown(controller.dispose);
    addTearDown(notes.dispose);
    await tester.pumpWidget(
      _notesApp(_notes, controller: controller, notesListenable: notes),
    );
    await tester.pumpAndSettle();

    controller.selectNote('long-note');
    await tester.pumpAndSettle();
    final original = _notes.last;
    notes.value = [
      _notes.first,
      Quicxec(
        id: original.id,
        title: 'Remote title',
        text: original.text,
        created: original.created,
        updatedAt: original.updatedAt.add(const Duration(minutes: 1)),
      ),
    ];
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('selected-note-preview')),
        matching: find.text('Remote title'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Edit note'));
    await tester.pumpAndSettle();
    notes.value = [
      _notes.first,
      Quicxec(
        id: original.id,
        title: 'Remote title again',
        text: original.text,
        created: original.created,
        updatedAt: original.updatedAt.add(const Duration(minutes: 2)),
      ),
    ];
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('inline-note-editor')),
        matching: find.text('Remote title again'),
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Local draft',
    );
    notes.value = [
      _notes.first,
      Quicxec(
        id: original.id,
        title: 'Remote title third',
        text: original.text,
        created: original.created,
        updatedAt: original.updatedAt.add(const Duration(minutes: 3)),
      ),
    ];
    await tester.pumpAndSettle();
    expect(find.text('Local draft'), findsOneWidget);
    expect(find.textContaining('changed elsewhere'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back navigation protects an unsaved inline draft', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 900));
    final controller = NotesController()..openAllNotes();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_notesApp(_notes, controller: controller));
    await tester.pumpAndSettle();

    controller.selectNote('long-note');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Navigation draft',
    );
    await tester.tap(find.byTooltip('Back to notes'));
    await tester.pumpAndSettle();
    expect(find.text('Save changes to this note?'), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(controller.location, NotesLocation.allNotes);
    expect(find.text('Navigation draft'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(controller.location, NotesLocation.root);
    expect(find.byKey(const Key('inline-note-editor')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a transient loading state keeps the inline draft', (
    tester,
  ) async {
    _setViewport(tester, const Size(1200, 900));
    final controller = NotesController()..openAllNotes();
    final states = ValueNotifier<DataState<List<Quicxec>>>(DataReady(_notes));
    addTearDown(controller.dispose);
    addTearDown(states.dispose);
    await tester.pumpWidget(
      _notesApp(_notes, controller: controller, notesStateListenable: states),
    );
    await tester.pumpAndSettle();

    controller.selectNote('long-note');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Loading draft',
    );
    states.value = const DataLoading<List<Quicxec>>();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inline-note-editor')), findsOneWidget);
    expect(find.text('Loading draft'), findsOneWidget);
    expect(find.textContaining('draft is preserved'), findsOneWidget);

    states.value = DataReady(_notes);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inline-note-editor')), findsOneWidget);
    expect(find.text('Loading draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final _notes = [
  Quicxec(
    id: 'short-note',
    title: 'Short note',
    text: 'One line',
    created: DateTime(2026, 8, 24, 9),
  ),
  Quicxec(
    id: 'long-note',
    title: 'Long note',
    text: List.filled(18, 'A longer note preview').join(' '),
    tags: const ['planning', 'ideas'],
    created: DateTime(2026, 8, 24, 10),
  ),
];

Widget _notesApp(
  List<Quicxec> notes, {
  List<NoteFolder> folders = const [],
  NotesController? controller,
  NoteRepository? repository,
  ValueNotifier<List<Quicxec>>? notesListenable,
  ValueNotifier<DataState<List<Quicxec>>>? notesStateListenable,
}) => MultiProvider(
  providers: [
    Provider<DataState<List<NoteFolder>>>.value(value: DataReady(folders)),
    Provider<DataState<models.Tags>>.value(value: DataEmpty(models.Tags())),
    Provider<NoteRepository>.value(value: repository ?? _FakeNoteRepository()),
    ChangeNotifierProvider.value(
      value: controller ?? (NotesController()..openAllNotes()),
    ),
  ],
  child: MaterialApp(
    theme: AppThemes.forPreset(AppThemePreset.midnight),
    home:
        notesStateListenable != null
            ? ValueListenableBuilder<DataState<List<Quicxec>>>(
              valueListenable: notesStateListenable,
              builder:
                  (context, noteState, _) =>
                      Provider<DataState<List<Quicxec>>>.value(
                        value: noteState,
                        child: const Scaffold(body: Quicxecs()),
                      ),
            )
            : notesListenable == null
            ? Provider<DataState<List<Quicxec>>>.value(
              value: DataReady(notes),
              child: const Scaffold(body: Quicxecs()),
            )
            : ValueListenableBuilder<List<Quicxec>>(
              valueListenable: notesListenable,
              builder:
                  (context, currentNotes, _) =>
                      Provider<DataState<List<Quicxec>>>.value(
                        value: DataReady(currentNotes),
                        child: const Scaffold(body: Quicxecs()),
                      ),
            ),
  ),
);

int _columnCount(WidgetTester tester) {
  final grid = tester.widget<MasonryGridView>(
    find.byKey(const Key('notes-masonry-grid')),
  );
  return (grid.gridDelegate as SliverSimpleGridDelegateWithFixedCrossAxisCount)
      .crossAxisCount;
}

class _FakeNoteRepository implements NoteRepository {
  Quicxec? addedNote;
  UpdateNoteCommand? updatedNote;
  Quicxec? archivedNote;

  @override
  Stream<DataState<List<Quicxec>>> watchNotes() =>
      Stream.value(const DataEmpty([]));

  @override
  Future<void> addNote(Quicxec note) async => addedNote = note;

  @override
  Future<void> updateNote(UpdateNoteCommand command) async =>
      updatedNote = command;

  @override
  Future<void> moveNote(String noteId, String? folderId) async {}

  @override
  Future<void> setChecklistItemChecked(
    Quicxec note,
    String itemId,
    bool isChecked,
  ) async {}

  @override
  Future<void> toggleTrashed(Quicxec note) async => archivedNote = note;

  @override
  Future<void> emptyTrash() async {}

  @override
  Future<void> deletePermanently(Quicxec note) async {}
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}
