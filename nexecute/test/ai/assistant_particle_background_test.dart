import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  test('generates a stable bounded particle field from a seed', () {
    final first = AssistantParticleField.deterministic(count: 40, seed: 17);
    final second = AssistantParticleField.deterministic(count: 40, seed: 17);
    final different = AssistantParticleField.deterministic(count: 40, seed: 18);

    expect(first.particles, second.particles);
    expect(first.particles, isNot(different.particles));
    expect(first.particles, hasLength(40));
    for (final particle in first.particles) {
      expect(particle.normalizedPosition.dx, inInclusiveRange(0, 1));
      expect(particle.normalizedPosition.dy, inInclusiveRange(0, 1));
      expect(particle.radius * 2, inInclusiveRange(1, 2.1));
      expect(particle.opacity, inInclusiveRange(0.1, 0.28));
      expect(particle.colorIndex, inInclusiveRange(0, 1));
    }
  });

  test('scales and bounds particle count for the viewport', () {
    expect(
      AssistantParticleField.countFor(const Size(100, 100)),
      AssistantParticleField.minimumCount,
    );
    expect(AssistantParticleField.countFor(const Size(800, 600)), 48);
    expect(
      AssistantParticleField.countFor(const Size(4000, 3000)),
      AssistantParticleField.maximumCount,
    );
  });

  testWidgets('keeps the decorative layer behind interactive content', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssistantParticleBackground(
            child: Center(
              child: FilledButton(
                onPressed: () => presses++,
                child: const Text('Continue'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('assistant-particle-layer')), findsOneWidget);
    expect(find.byKey(const Key('assistant-particle-paint')), findsOneWidget);
    expect(
      tester
          .widget<IgnorePointer>(
            find.byKey(const Key('assistant-particle-layer')),
          )
          .ignoring,
      isTrue,
    );

    await tester.tap(find.text('Continue'));
    expect(presses, 1);
  });

  testWidgets('derives its canvas and dot colors from the active theme', (
    tester,
  ) async {
    const background = Color(0xFF010203);
    const primary = Color(0xFF112233);
    const secondary = Color(0xFF445566);
    final theme = ThemeData(
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
      ).copyWith(primary: primary, secondary: secondary),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const AssistantParticleBackground(child: SizedBox.expand()),
      ),
    );

    final paint = tester.widget<CustomPaint>(
      find.byKey(const Key('assistant-particle-paint')),
    );
    final painter = paint.painter! as AssistantParticlePainter;
    expect(painter.backgroundColor, background);
    expect(painter.particleColors, const [primary, secondary]);
  });
}
