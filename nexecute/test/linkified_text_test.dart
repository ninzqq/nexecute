import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/home/widgets/linkified_text.dart';

void main() {
  testWidgets('turns web addresses into tappable links', (tester) async {
    final opened = <Uri>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LinkifiedText(
            key: const Key('linked-note'),
            'See https://example.com/docs, then www.example.org.',
            onOpenLink: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      ),
    );

    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(const Key('linked-note')),
        matching: find.byType(RichText),
      ),
    );
    final root = richText.text as TextSpan;
    final links =
        _flatten(root).where((span) => span.recognizer != null).toList();

    expect(links.map((span) => span.text), [
      'https://example.com/docs',
      'www.example.org',
    ]);

    (links.first.recognizer! as TapGestureRecognizer).onTap!();
    (links.last.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pump();

    expect(opened, [
      Uri.parse('https://example.com/docs'),
      Uri.parse('https://www.example.org'),
    ]);
  });

  testWidgets('keeps ordinary note text unchanged', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LinkifiedText('Remember to buy milk.')),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText));
    final root = richText.text as TextSpan;

    expect(root.toPlainText(), 'Remember to buy milk.');
    expect(
      root.children!.whereType<TextSpan>().any(
        (span) => span.recognizer != null,
      ),
      isFalse,
    );
  });
}

Iterable<TextSpan> _flatten(TextSpan span) sync* {
  yield span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    if (child case final TextSpan textSpan) yield* _flatten(textSpan);
  }
}
