import 'package:flutter/material.dart';
import 'package:nexecute/ai/presentation/assistant_particle_background.dart';

/// Hosts one persistent particle field behind every route in the application.
///
/// Structural page surfaces are transparent so the field remains visible,
/// while cards, dialogs, sheets, navigation chrome, and other content surfaces
/// retain their theme colors for readability.
class AppParticleBackground extends StatelessWidget {
  const AppParticleBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AssistantParticleBackground(
      child: Theme(
        data: theme.copyWith(scaffoldBackgroundColor: Colors.transparent),
        child: child,
      ),
    );
  }
}
