import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/home/bottomsheets/item_editor_sheet.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/note_folder.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/tag.dart' as models;
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('converts plain note lines into editable checklist items', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final note = Quicxec(
      id: 'note-1',
      title: 'Shopping',
      text: 'Milk\nBread',
      created: DateTime(2026, 8, 24),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DataState<models.Tags>>.value(
            value: DataEmpty(models.Tags()),
          ),
          Provider<DataState<List<NoteFolder>>>.value(
            value: const DataEmpty([]),
          ),
        ],
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ItemEditorSheet(quicxec: note, isEditing: true),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Checklist'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note-checklist-editor')), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Bread'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('add-checklist-item')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Remove checklist item'), findsNWidgets(3));

    final checklistFields = find.descendant(
      of: find.byKey(const Key('note-checklist-editor')),
      matching: find.byType(EditableText),
    );
    final newItemField = tester.widget<EditableText>(checklistFields.last);
    expect(newItemField.focusNode.hasFocus, isTrue);

    tester.testTextInput.enterText('Eggs');
    await tester.pump();

    expect(find.text('Eggs'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove checklist item').last);
    await tester.pump();

    expect(find.byTooltip('Remove checklist item'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('saves a titleless checklist and awaits persistence', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final draft = Quicxec(
      id: '',
      title: '',
      text: 'Milk\nBread',
      created: DateTime(2026, 8, 24),
    );
    Quicxec? savedNote;
    var saveCompleted = false;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DataState<models.Tags>>.value(
            value: DataEmpty(models.Tags()),
          ),
          Provider<DataState<List<NoteFolder>>>.value(
            value: const DataEmpty([]),
          ),
        ],
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ItemEditorSheet(
                quicxec: draft,
                onSaveQuicxec: (note, isExisting) async {
                  expect(isExisting, isFalse);
                  savedNote = note;
                  await Future<void>.delayed(const Duration(milliseconds: 50));
                  saveCompleted = true;
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Checklist'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(saveCompleted, isFalse);

    await tester.pumpAndSettle();

    expect(saveCompleted, isTrue);
    expect(savedNote, isNotNull);
    expect(savedNote!.title, isEmpty);
    expect(savedNote!.contentType, NoteContentType.checklist);
    expect(savedNote!.checklistItems, hasLength(2));
    expect(savedNote!.text, 'Milk\nBread');
  });

  testWidgets('assigns a note to a folder from the editor', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final folder = NoteFolder(
      id: 'projects',
      name: 'Projects',
      createdAt: DateTime(2026, 8, 28),
      updatedAt: DateTime(2026, 8, 28),
    );
    Quicxec? savedNote;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DataState<models.Tags>>.value(
            value: DataEmpty(models.Tags()),
          ),
          Provider<DataState<List<NoteFolder>>>.value(
            value: DataReady([folder]),
          ),
        ],
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ItemEditorSheet(
                quicxec: Quicxec(
                  id: '',
                  text: 'Reference',
                  created: DateTime(2026, 8, 28),
                ),
                onSaveQuicxec: (note, _) async => savedNote = note,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('note-folder-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Projects').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedNote?.folderId, folder.id);
  });
}
