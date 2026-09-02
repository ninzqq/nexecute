import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/home/screens/trashscreen.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('desktop trash cards grow to fit long note previews', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final note = Quicxec(
      id: 'long-note',
      title: 'Firestore savings and architecture notes',
      text: List.generate(
        8,
        (index) => 'Detailed line ${index + 1} that needs room in the preview.',
      ).join('\n'),
      created: DateTime(2026, 9, 2),
      trashed: true,
    );

    await tester.pumpWidget(
      Provider<DataState<List<Quicxec>>>.value(
        value: DataReady([note]),
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.cyberpunk),
          home: const TrashScreen(embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trash-notes-grid')), findsOneWidget);
    expect(find.byKey(const ValueKey('trash-note-long-note')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('trash-note-long-note'))).height,
      greaterThan(120),
    );
    expect(tester.takeException(), isNull);
  });
}
