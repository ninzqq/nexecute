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
    final notes = [
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

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DataState<List<Quicxec>>>.value(value: DataReady(notes)),
          Provider<DataState<List<NoteFolder>>>.value(
            value: const DataEmpty([]),
          ),
          ChangeNotifierProvider.value(
            value: NotesController()..openAllNotes(),
          ),
        ],
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: const Scaffold(body: Quicxecs()),
        ),
      ),
    );
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
}
