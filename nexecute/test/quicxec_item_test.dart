import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/home/widgets/quicxecitem.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/themes.dart';

void main() {
  testWidgets('long-pressing a note opens its action sheet', (tester) async {
    final note = Quicxec(
      id: 'note-1',
      title: 'Meeting notes',
      text: 'Discuss the next release',
      created: DateTime(2026, 8, 24, 9),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemes.forPreset(AppThemePreset.midnight),
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 120,
            child: QuicxecItem(quicxec: note),
          ),
        ),
      ),
    );

    await tester.longPress(find.byType(QuicxecItem));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Meeting notes'), findsWidgets);
    expect(find.text('Note actions'), findsOneWidget);
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
      MaterialApp(
        theme: AppThemes.forPreset(AppThemePreset.neutral),
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 120,
            child: QuicxecItem(quicxec: note),
          ),
        ),
      ),
    );

    await tester.longPress(find.byType(QuicxecItem));
    await tester.pumpAndSettle();

    expect(find.text('Restore note'), findsOneWidget);
    expect(find.text('Delete permanently'), findsOneWidget);
    expect(find.text('This action cannot be undone'), findsOneWidget);
    expect(find.byIcon(Icons.restore_from_trash_rounded), findsOneWidget);
    expect(find.byIcon(Icons.delete_forever_rounded), findsOneWidget);
  });
}
