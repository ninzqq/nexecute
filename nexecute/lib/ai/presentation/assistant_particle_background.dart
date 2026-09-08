import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

@immutable
final class AssistantParticle {
  const AssistantParticle({
    required this.normalizedPosition,
    required this.radius,
    required this.opacity,
    required this.colorIndex,
  });

  final Offset normalizedPosition;
  final double radius;
  final double opacity;
  final int colorIndex;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssistantParticle &&
          normalizedPosition == other.normalizedPosition &&
          radius == other.radius &&
          opacity == other.opacity &&
          colorIndex == other.colorIndex;

  @override
  int get hashCode =>
      Object.hash(normalizedPosition, radius, opacity, colorIndex);
}

@immutable
final class AssistantParticleField {
  const AssistantParticleField(this.particles);

  factory AssistantParticleField.deterministic({
    required int count,
    int seed = defaultSeed,
    int colorCount = 2,
  }) {
    assert(count >= 0);
    assert(colorCount > 0);
    final random = math.Random(seed);
    return AssistantParticleField(
      List.unmodifiable([
        for (var index = 0; index < count; index++)
          AssistantParticle(
            normalizedPosition: Offset(
              random.nextDouble(),
              random.nextDouble(),
            ),
            radius: 0.5 + random.nextDouble() * 0.55,
            opacity: 0.1 + random.nextDouble() * 0.18,
            colorIndex: random.nextInt(colorCount),
          ),
      ]),
    );
  }

  static const int defaultSeed = 0x4E455845;
  static const int minimumCount = 25;
  static const int maximumCount = 60;

  final List<AssistantParticle> particles;

  static int countFor(Size viewport) =>
      (viewport.width * viewport.height / 10000).round().clamp(
        minimumCount,
        maximumCount,
      );
}

final class AssistantParticlePainter extends CustomPainter {
  const AssistantParticlePainter({
    required this.field,
    required this.backgroundColor,
    required this.particleColors,
  }) : assert(particleColors.length > 0);

  final AssistantParticleField field;
  final Color backgroundColor;
  final List<Color> particleColors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
    final paint = Paint();
    for (final particle in field.particles) {
      paint.color = particleColors[particle.colorIndex % particleColors.length]
          .withValues(alpha: particle.opacity);
      canvas.drawCircle(
        Offset(
          particle.normalizedPosition.dx * size.width,
          particle.normalizedPosition.dy * size.height,
        ),
        particle.radius,
        paint,
      );
    }
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(covariant AssistantParticlePainter oldDelegate) =>
      oldDelegate.field.particles.length != field.particles.length ||
      !listEquals(oldDelegate.field.particles, field.particles) ||
      oldDelegate.backgroundColor != backgroundColor ||
      !listEquals(oldDelegate.particleColors, particleColors);
}

class AssistantParticleBackground extends StatelessWidget {
  const AssistantParticleBackground({
    super.key,
    required this.child,
    this.seed = AssistantParticleField.defaultSeed,
  });

  final Widget child;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        final field = AssistantParticleField.deterministic(
          count: AssistantParticleField.countFor(viewport),
          seed: seed,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              key: const Key('assistant-particle-layer'),
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(
                    key: const Key('assistant-particle-paint'),
                    painter: AssistantParticlePainter(
                      field: field,
                      backgroundColor: theme.scaffoldBackgroundColor,
                      particleColors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        );
      },
    );
  }
}
