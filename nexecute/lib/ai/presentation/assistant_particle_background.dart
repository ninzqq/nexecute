import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nexecute/themes.dart';

@immutable
final class AssistantParticle {
  const AssistantParticle({
    required this.normalizedPosition,
    required this.radius,
    required this.opacity,
    required this.colorIndex,
    required this.velocity,
    required this.twinklePhase,
    required this.twinkleAngularVelocity,
  });

  final Offset normalizedPosition;
  final double radius;
  final double opacity;
  final int colorIndex;
  final Offset velocity;
  final double twinklePhase;
  final double twinkleAngularVelocity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssistantParticle &&
          normalizedPosition == other.normalizedPosition &&
          radius == other.radius &&
          opacity == other.opacity &&
          colorIndex == other.colorIndex &&
          velocity == other.velocity &&
          twinklePhase == other.twinklePhase &&
          twinkleAngularVelocity == other.twinkleAngularVelocity;

  @override
  int get hashCode => Object.hash(
    normalizedPosition,
    radius,
    opacity,
    colorIndex,
    velocity,
    twinklePhase,
    twinkleAngularVelocity,
  );
}

@immutable
final class AssistantParticleField {
  const AssistantParticleField(this.particles);

  factory AssistantParticleField.deterministic({
    required int count,
    int seed = defaultSeed,
    int colorCount = 2,
    double minimumRadius = 0.5,
    double maximumRadius = 1.35,
    double minimumOpacity = 0.1,
    double maximumOpacity = 0.28,
    double minimumSpeed = 3,
    double maximumSpeed = 7,
    double minimumTwinklePeriod = 6,
    double maximumTwinklePeriod = 12,
  }) {
    assert(count >= 0);
    assert(colorCount > 0);
    assert(minimumRadius <= maximumRadius);
    assert(minimumOpacity <= maximumOpacity);
    assert(minimumSpeed <= maximumSpeed);
    assert(minimumTwinklePeriod > 0);
    assert(minimumTwinklePeriod <= maximumTwinklePeriod);
    final random = math.Random(seed);
    return AssistantParticleField(
      List.unmodifiable([
        for (var index = 0; index < count; index++)
          _createParticle(
            random,
            colorCount,
            minimumRadius: minimumRadius,
            maximumRadius: maximumRadius,
            minimumOpacity: minimumOpacity,
            maximumOpacity: maximumOpacity,
            minimumSpeed: minimumSpeed,
            maximumSpeed: maximumSpeed,
            minimumTwinklePeriod: minimumTwinklePeriod,
            maximumTwinklePeriod: maximumTwinklePeriod,
          ),
      ]),
    );
  }

  static const int defaultSeed = 0x4E455845;
  static const int minimumCount = 25;
  static const int maximumCount = 100;

  final List<AssistantParticle> particles;

  static AssistantParticle _createParticle(
    math.Random random,
    int colorCount, {
    required double minimumRadius,
    required double maximumRadius,
    required double minimumOpacity,
    required double maximumOpacity,
    required double minimumSpeed,
    required double maximumSpeed,
    required double minimumTwinklePeriod,
    required double maximumTwinklePeriod,
  }) {
    final direction = random.nextDouble() * math.pi * 2;
    final speed = _between(random, minimumSpeed, maximumSpeed);
    final twinklePeriod = _between(
      random,
      minimumTwinklePeriod,
      maximumTwinklePeriod,
    );
    return AssistantParticle(
      normalizedPosition: Offset(random.nextDouble(), random.nextDouble()),
      radius: _between(random, minimumRadius, maximumRadius),
      opacity: _between(random, minimumOpacity, maximumOpacity),
      colorIndex: random.nextInt(colorCount),
      velocity: Offset(
        math.cos(direction) * speed,
        math.sin(direction) * speed,
      ),
      twinklePhase: random.nextDouble() * math.pi * 2,
      twinkleAngularVelocity: math.pi * 2 / twinklePeriod,
    );
  }

  static double _between(math.Random random, double minimum, double maximum) =>
      minimum + random.nextDouble() * (maximum - minimum);

  static int countFor(
    Size viewport, {
    double areaPerParticle = 10000,
    int minimum = minimumCount,
    int maximum = maximumCount,
  }) => (viewport.width * viewport.height / areaPerParticle).round().clamp(
    minimum,
    maximum,
  );
}

final class AssistantParticlePainter extends CustomPainter {
  AssistantParticlePainter({
    required this.field,
    required this.backgroundColor,
    required this.particleColors,
    required this.animation,
    required this.motionEnabled,
    required this.twinkleStrength,
  }) : assert(particleColors.isNotEmpty),
       super(repaint: animation);

  final AssistantParticleField field;
  final Color backgroundColor;
  final List<Color> particleColors;
  final Animation<double> animation;
  final bool motionEnabled;
  final double twinkleStrength;

  double get elapsedSeconds => animation.value;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
    final paint = Paint();
    for (final particle in field.particles) {
      paint.color = particleColors[particle.colorIndex % particleColors.length]
          .withValues(
            alpha: opacityFor(particle, elapsedSeconds, twinkleStrength),
          );
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

  static double opacityFor(
    AssistantParticle particle,
    double elapsedSeconds,
    double twinkleStrength,
  ) => (particle.opacity *
          (1 +
              math.sin(
                    particle.twinklePhase +
                        particle.twinkleAngularVelocity * elapsedSeconds,
                  ) *
                  twinkleStrength))
      .clamp(0, 1);

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(covariant AssistantParticlePainter oldDelegate) =>
      oldDelegate.field.particles.length != field.particles.length ||
      !listEquals(oldDelegate.field.particles, field.particles) ||
      oldDelegate.backgroundColor != backgroundColor ||
      !listEquals(oldDelegate.particleColors, particleColors) ||
      oldDelegate.animation != animation ||
      oldDelegate.twinkleStrength != twinkleStrength;
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
    final particleTheme =
        theme.extension<AssistantParticleTheme>() ??
        AssistantParticleTheme.fallback(theme.colorScheme);
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        final field = AssistantParticleField.deterministic(
          count: AssistantParticleField.countFor(
            viewport,
            areaPerParticle: particleTheme.areaPerParticle,
            minimum: particleTheme.minimumCount,
            maximum: particleTheme.maximumCount,
          ),
          seed: widget.seed,
          colorCount: particleTheme.colors.length,
          minimumRadius: particleTheme.minimumRadius,
          maximumRadius: particleTheme.maximumRadius,
          minimumOpacity: particleTheme.minimumOpacity,
          maximumOpacity: particleTheme.maximumOpacity,
          minimumSpeed: particleTheme.minimumSpeed,
          maximumSpeed: particleTheme.maximumSpeed,
          minimumTwinklePeriod: particleTheme.minimumTwinklePeriod,
          maximumTwinklePeriod: particleTheme.maximumTwinklePeriod,
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
                        particleColors: particleTheme.colors,
                        animation: _controller,
                        motionEnabled: _motionEnabled ?? false,
                        twinkleStrength: particleTheme.twinkleStrength,
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
