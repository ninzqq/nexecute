import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  testWidgets('shows safe diagnostic details and recovery suggestions', (
    tester,
  ) async {
    var actionCalled = false;
    final diagnostic = AiDiagnostic(
      kind: AiDiagnosticKind.tls,
      title: 'Secure connection failed',
      summary: 'The endpoint certificate could not be verified.',
      suggestions: const [
        'Check the certificate name and trust chain.',
        'Confirm that the device clock is correct.',
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiDiagnosticPanel(
            diagnostic: diagnostic,
            onAction: () => actionCalled = true,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('ai-diagnostic-tls')), findsOneWidget);
    expect(find.text('Secure connection failed'), findsOneWidget);
    expect(
      find.text('The endpoint certificate could not be verified.'),
      findsOneWidget,
    );
    expect(
      find.text('• Check the certificate name and trust chain.'),
      findsOneWidget,
    );
    expect(
      find.text('• Confirm that the device clock is correct.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('ai-diagnostic-action-tls')));
    expect(actionCalled, isTrue);
  });
}
