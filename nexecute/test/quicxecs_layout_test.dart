import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/home/widgets/quicxecs.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/quicxec.dart';
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

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();
    expect(_columnCount(tester), 4);
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

Widget _notesApp(List<Quicxec> notes) => MultiProvider(
  providers: [
    Provider<DataState<List<Quicxec>>>.value(value: DataReady(notes)),
    Provider<DataState<List<NoteFolder>>>.value(value: const DataEmpty([])),
    ChangeNotifierProvider.value(value: NotesController()..openAllNotes()),
  ],
  child: MaterialApp(
    theme: AppThemes.forPreset(AppThemePreset.midnight),
    home: const Scaffold(body: Quicxecs()),
  ),
);

int _columnCount(WidgetTester tester) {
  final grid = tester.widget<MasonryGridView>(
    find.byKey(const Key('notes-masonry-grid')),
  );
  return (grid.gridDelegate as SliverSimpleGridDelegateWithFixedCrossAxisCount)
      .crossAxisCount;
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}
