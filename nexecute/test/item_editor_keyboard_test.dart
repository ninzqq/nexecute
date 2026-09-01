import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/home/bottomsheets/item_editor.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/note_folder.dart';
import 'package:nexecute/models/tag.dart' as models;
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';

import 'support/fake_event_repository.dart';

void main() {
  testWidgets('keeps event Save above the Android keyboard and tappable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    final repository = FakeEventRepository();
    final startTime = DateTime(2026, 9, 2, 9);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<EventRepository>.value(value: repository),
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
                  body: Center(
                    child: FilledButton(
                      onPressed:
                          () => showItemEditor(
                            context,
                            event: Event(
                              id: '',
                              title: '',
                              startTime: startTime,
                              endTime: startTime.add(const Duration(hours: 1)),
                            ),
                          ),
                      child: const Text('New event'),
                    ),
                  ),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('New event'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Keyboard-safe event',
    );

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    const keyboardTop = 500.0;
    final saveButton = find.byKey(const Key('item-editor-submit-button'));
    expect(find.byKey(const Key('item-editor-sticky-actions')), findsOneWidget);
    expect(
      tester.getBottomRight(saveButton).dy,
      lessThanOrEqualTo(keyboardTop),
    );
    expect(saveButton.hitTestable(), findsOneWidget);

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.addedEvent?.title, 'Keyboard-safe event');
    expect(find.text('Save'), findsNothing);
  });
}
