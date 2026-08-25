import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/home/bottomsheets/item_editor_sheet.dart';
import 'package:nexecute/models/data_state.dart';
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
    await tester.pump();

    expect(find.byTooltip('Remove checklist item'), findsNWidgets(3));
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
}
