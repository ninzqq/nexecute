import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/home/bottomsheets/item_editor.dart';
import 'package:nexecute/home/bottomsheets/item_editor_header.dart';
import 'package:nexecute/home/bottomsheets/item_editor_sheet.dart';
import 'package:nexecute/home/screens/tagsscreen.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/note_folder.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/tag.dart' as models;
import 'package:nexecute/tasks/todo_editor_sheet.dart';
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('note and event editors request sentence capitalization', (
    tester,
  ) async {
    await _pumpItemEditor(
      tester,
      ItemEditorSheet(
        key: const ValueKey('tall-note-editor'),
        quicxec: Quicxec(id: '', text: '', created: DateTime(2026, 8, 28)),
      ),
    );
    _expectSentenceCapitalization(tester);

    await _pumpItemEditor(
      tester,
      ItemEditorSheet(
        key: const ValueKey('tall-event-editor'),
        event: Event(
          id: '',
          title: '',
          startTime: DateTime(2026, 8, 28, 9),
          endTime: DateTime(2026, 8, 28, 10),
        ),
      ),
    );
    _expectSentenceCapitalization(tester);
  });

  testWidgets('task and tag creation request sentence capitalization', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemes.forPreset(AppThemePreset.midnight),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showTodoEditor(context),
                  child: const Text('Open task editor'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('Open task editor'));
    await tester.pumpAndSettle();
    _expectSentenceCapitalization(tester);

    await tester.pumpWidget(
      Provider<DataState<models.Tags>>.value(
        value: DataEmpty(models.Tags()),
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: const TagsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).textCapitalization,
      TextCapitalization.sentences,
    );
  });

  testWidgets('note and event descriptions provide taller writing areas', (
    tester,
  ) async {
    await _pumpItemEditor(
      tester,
      ItemEditorSheet(
        key: const ValueKey('description-note-editor'),
        quicxec: Quicxec(id: '', text: '', created: DateTime(2026, 8, 28)),
      ),
    );

    var description = _descriptionField(tester);
    expect(description.minLines, 6);
    expect(description.maxLines, 18);

    await _pumpItemEditor(
      tester,
      ItemEditorSheet(
        key: const ValueKey('description-event-editor'),
        event: Event(
          id: '',
          title: '',
          startTime: DateTime(2026, 8, 28, 9),
          endTime: DateTime(2026, 8, 28, 10),
        ),
      ),
    );

    description = _descriptionField(tester);
    expect(description.minLines, 4);
    expect(description.maxLines, 8);
  });

  testWidgets('item editor keeps selectors compact at narrow widths', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpItemEditor(
      tester,
      ItemEditorSheet(
        quicxec: Quicxec(id: '', text: '', created: DateTime(2026, 8, 28)),
      ),
    );

    final header = tester.getRect(find.byType(ItemEditorHeader));
    final format = tester.getRect(
      find.byKey(const Key('note-format-selector')),
    );
    final description = tester.getRect(
      find.byKey(const Key('note-description-field')),
    );

    expect(header.height, lessThanOrEqualTo(40));
    expect(format.height, lessThanOrEqualTo(40));
    expect(find.text('Note format'), findsNothing);
    expect(description.top, lessThan(200));

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('note-format-selector')),
        matching: find.text('Checklist'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('note-checklist-editor')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('note-format-selector'))).height,
      lessThanOrEqualTo(40),
    );

    await tester.tap(
      find.descendant(
        of: find.byType(ItemEditorHeader),
        matching: find.text('Event'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('note-format-selector')), findsNothing);
    expect(
      tester.getSize(find.byType(ItemEditorHeader)).height,
      lessThanOrEqualTo(48),
    );

    await tester.tap(
      find.descendant(
        of: find.byType(ItemEditorHeader),
        matching: find.text('Note'),
      ),
    );
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(280, 844);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(ItemEditorHeader)).height,
      lessThanOrEqualTo(96),
    );
    expect(
      tester.getSize(find.byKey(const Key('note-format-selector'))).height,
      lessThanOrEqualTo(40),
    );
    expect(find.text('Note format'), findsNothing);

    tester.view.physicalSize = const Size(440, 844);
    await tester.pumpAndSettle();
    expect(find.text('Note format'), findsOneWidget);

    tester.view.physicalSize = const Size(700, 844);
    await tester.pumpAndSettle();
    expect(find.byType(ItemEditorHeader), findsOneWidget);
    expect(find.byKey(const Key('note-format-selector')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('note description fills bounded phone and medium editors', (
    tester,
  ) async {
    for (final width in [390.0, 700.0]) {
      await _pumpBoundedNoteEditor(tester, Size(width, 500));

      final description = find.byKey(const Key('note-description-field'));
      final compactHeight = tester.getSize(description).height;
      expect(_descriptionField(tester).expands, isTrue);
      expect(compactHeight, greaterThan(40));
      expect(
        tester
            .getRect(find.byKey(const Key('item-editor-sticky-actions')))
            .bottom,
        tester.getRect(find.byType(ItemEditorSheet)).bottom,
      );
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = Size(width, 844);
      await tester.pumpAndSettle();

      expect(
        tester.getSize(description).height,
        greaterThan(compactHeight + 250),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('note description fills a short desktop dialog', (tester) async {
    tester.view.physicalSize = const Size(1000, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed:
                        () => showItemEditor(
                          context,
                          quicxec: Quicxec(
                            id: '',
                            text: '',
                            created: DateTime(2026, 8, 28),
                          ),
                        ),
                    child: const Text('Open note'),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open note'));
    await tester.pumpAndSettle();

    final description = find.byKey(const Key('note-description-field'));
    expect(find.byKey(const Key('desktop-item-editor-dialog')), findsOneWidget);
    expect(_descriptionField(tester).expands, isTrue);
    expect(tester.getSize(description).height, greaterThan(40));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpItemEditor(WidgetTester tester, Widget editor) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<DataState<models.Tags>>.value(value: DataEmpty(models.Tags())),
        Provider<DataState<List<NoteFolder>>>.value(value: const DataEmpty([])),
      ],
      child: MaterialApp(
        theme: AppThemes.forPreset(AppThemePreset.midnight),
        home: Scaffold(body: SingleChildScrollView(child: editor)),
      ),
    ),
  );
}

Future<void> _pumpBoundedNoteEditor(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<DataState<models.Tags>>.value(value: DataEmpty(models.Tags())),
        Provider<DataState<List<NoteFolder>>>.value(value: const DataEmpty([])),
      ],
      child: MaterialApp(
        theme: AppThemes.forPreset(AppThemePreset.midnight),
        home: Scaffold(
          body: ItemEditorSheet(
            quicxec: Quicxec(id: '', text: '', created: DateTime(2026, 8, 28)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectSentenceCapitalization(WidgetTester tester) {
  final fields = tester.widgetList<EditableText>(find.byType(EditableText));
  expect(fields, isNotEmpty);
  for (final field in fields) {
    expect(field.textCapitalization, TextCapitalization.sentences);
  }
}

EditableText _descriptionField(WidgetTester tester) {
  final descriptionField = find.widgetWithText(TextFormField, 'Description');
  return tester.widget<EditableText>(
    find.descendant(of: descriptionField, matching: find.byType(EditableText)),
  );
}
