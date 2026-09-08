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
    required this.velocity,
  });

  final Offset normalizedPosition;
  final double radius;
  final double opacity;
  final int colorIndex;
  final Offset velocity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssistantParticle &&
          normalizedPosition == other.normalizedPosition &&
          radius == other.radius &&
          opacity == other.opacity &&
          colorIndex == other.colorIndex &&
          velocity == other.velocity;

  @override
  int get hashCode =>
      Object.hash(normalizedPosition, radius, opacity, colorIndex, velocity);
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
          _createParticle(random, colorCount),
      ]),
    );
  }

  static const int defaultSeed = 0x4E455845;
  static const int minimumCount = 25;
  static const int maximumCount = 100;

  final List<AssistantParticle> particles;

  static AssistantParticle _createParticle(math.Random random, int colorCount) {
    final direction = random.nextDouble() * math.pi * 2;
    final speed = 3 + random.nextDouble() * 4;
    return AssistantParticle(
      normalizedPosition: Offset(random.nextDouble(), random.nextDouble()),
      radius: 0.5 + random.nextDouble() * 0.85,
      opacity: 0.1 + random.nextDouble() * 0.18,
      colorIndex: random.nextInt(colorCount),
      velocity: Offset(
        math.cos(direction) * speed,
        math.sin(direction) * speed,
      ),
    );
  }

  static int countFor(Size viewport) =>
      (viewport.width * viewport.height / 10000).round().clamp(
        minimumCount,
        maximumCount,
      );
}

final class AssistantParticlePainter extends CustomPainter {
  AssistantParticlePainter({
    required this.field,
    required this.backgroundColor,
    required this.particleColors,
    required this.animation,
    required this.motionEnabled,
  }) : assert(particleColors.isNotEmpty),
       super(repaint: animation);

  final AssistantParticleField field;
  final Color backgroundColor;
  final List<Color> particleColors;
  final Animation<double> animation;
  final bool motionEnabled;

  double get elapsedSeconds => animation.value;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
    final paint = Paint();
    for (final particle in field.particles) {
      paint.color = particleColors[particle.colorIndex % particleColors.length]
          .withValues(alpha: particle.opacity);
      canvas.drawCircle(
        positionFor(particle, size, elapsedSeconds),
        particle.radius,
        paint,
      );
    }
  }

  static Offset positionFor(
    AssistantParticle particle,
    Size viewport,
    double elapsedSeconds,
  ) => Offset(
    _wrap(
      particle.normalizedPosition.dx * viewport.width +
          particle.velocity.dx * elapsedSeconds,
      viewport.width,
    ),
    _wrap(
      particle.normalizedPosition.dy * viewport.height +
          particle.velocity.dy * elapsedSeconds,
      viewport.height,
    ),
  );

  static double _wrap(double value, double extent) =>
      extent <= 0 ? 0 : value % extent;

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(covariant AssistantParticlePainter oldDelegate) =>
      oldDelegate.field.particles.length != field.particles.length ||
      !listEquals(oldDelegate.field.particles, field.particles) ||
      oldDelegate.backgroundColor != backgroundColor ||
      !listEquals(oldDelegate.particleColors, particleColors) ||
      oldDelegate.animation != animation;
}

class AssistantParticleBackground extends StatefulWidget {
  const AssistantParticleBackground({
    super.key,
    required this.child,
    this.seed = AssistantParticleField.defaultSeed,
  });

  final Widget child;
  final int seed;

  @override
  State<AssistantParticleBackground> createState() =>
      _AssistantParticleBackgroundState();
}

class _AssistantParticleBackgroundState
    extends State<AssistantParticleBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool? _motionEnabled;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motionEnabled =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (_motionEnabled == motionEnabled) return;
    _motionEnabled = motionEnabled;
    if (motionEnabled) {
      _controller.animateWith(_ElapsedSecondsSimulation(_controller.value));
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        final field = AssistantParticleField.deterministic(
          count: AssistantParticleField.countFor(viewport),
          seed: widget.seed,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
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
                        animation: _controller,
                        motionEnabled: _motionEnabled ?? false,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}

final class _ElapsedSecondsSimulation extends Simulation {
  _ElapsedSecondsSimulation(this.initialSeconds);

  final double initialSeconds;

  @override
  double x(double time) => initialSeconds + time;

  @override
  double dx(double time) => 1;

  @override
  bool isDone(double time) => false;
}
