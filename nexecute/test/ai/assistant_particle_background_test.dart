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
      expect(particle.velocity.distance, inInclusiveRange(2, 6));
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

  test('moves particles independently and wraps them at viewport edges', () {
    const particle = AssistantParticle(
      normalizedPosition: Offset(0.99, 0.01),
      radius: 1,
      opacity: 0.2,
      colorIndex: 0,
      velocity: Offset(5, -5),
    );

    expect(
      AssistantParticlePainter.positionFor(particle, const Size(100, 100), 1),
      const Offset(4, 96),
    );
  });

  testWidgets('ticks only while its TickerMode is enabled', (tester) async {
    await tester.pumpWidget(_motionApp(tickerEnabled: true));
    final running = _particlePainter(tester);
    final initialValue = running.animation.value;

    await tester.pump(const Duration(seconds: 1));
    expect(running.animation.value, greaterThan(initialValue));
    final valueBeforePause = running.animation.value;

    await tester.pumpWidget(_motionApp(tickerEnabled: false));
    final paused = _particlePainter(tester);
    expect(paused.motionEnabled, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(paused.animation.value, valueBeforePause);

    await tester.pumpWidget(_motionApp(tickerEnabled: true));
    final resumed = _particlePainter(tester);
    expect(resumed.motionEnabled, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(resumed.animation.value, greaterThan(valueBeforePause));
  });

  testWidgets('keeps the field static when reduced motion is requested', (
    tester,
  ) async {
    await tester.pumpWidget(
      _motionApp(tickerEnabled: true, disableAnimations: true),
    );
    final painter = _particlePainter(tester);
    final initialValue = painter.animation.value;

    expect(painter.motionEnabled, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(painter.animation.value, initialValue);
  });

  testWidgets('preserves its field and animation across parent rebuilds', (
    tester,
  ) async {
    await tester.pumpWidget(_motionApp(tickerEnabled: true));
    await tester.pump(const Duration(seconds: 1));
    final before = _particlePainter(tester);
    final particles = before.field.particles;
    final animation = before.animation;
    final animationValue = animation.value;

    await tester.pumpWidget(_motionApp(tickerEnabled: true));
    final after = _particlePainter(tester);
    expect(after.field.particles, particles);
    expect(after.animation, same(animation));
    expect(after.animation.value, animationValue);
  });
}

Widget _motionApp({
  required bool tickerEnabled,
  bool disableAnimations = false,
}) => MaterialApp(
  builder:
      (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
  home: TickerMode(
    enabled: tickerEnabled,
    child: const AssistantParticleBackground(child: SizedBox.expand()),
  ),
);

AssistantParticlePainter _particlePainter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byKey(const Key('assistant-particle-paint')),
            )
            .painter!
        as AssistantParticlePainter;
