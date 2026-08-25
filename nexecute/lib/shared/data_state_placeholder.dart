import 'package:flutter/material.dart';

enum DataStatePresentation { loading, empty, unauthenticated, failure }

class DataStatePlaceholder extends StatelessWidget {
  const DataStatePlaceholder({
    super.key,
    required this.presentation,
    this.title,
    this.message,
    this.compact = false,
  });

  final DataStatePresentation presentation;
  final String? title;
  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final defaults = _defaultsFor(presentation);
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      key: ValueKey('data-state-${presentation.name}'),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 24,
          vertical: compact ? 12 : 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (presentation == DataStatePresentation.loading)
              const SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              Icon(
                defaults.icon,
                size: compact ? 28 : 46,
                color:
                    presentation == DataStatePresentation.failure
                        ? colorScheme.error
                        : colorScheme.secondary,
              ),
            SizedBox(height: compact ? 8 : 14),
            Text(
              title ?? defaults.title,
              textAlign: TextAlign.center,
              style:
                  compact
                      ? Theme.of(context).textTheme.titleSmall
                      : Theme.of(context).textTheme.titleMedium,
            ),
            if ((message ?? defaults.message).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message ?? defaults.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _DataStateDefaults _defaultsFor(DataStatePresentation presentation) {
    return switch (presentation) {
      DataStatePresentation.loading => const _DataStateDefaults(
        icon: Icons.sync_rounded,
        title: 'Loading…',
        message: 'Fetching your latest data.',
      ),
      DataStatePresentation.empty => const _DataStateDefaults(
        icon: Icons.inbox_outlined,
        title: 'Nothing here yet',
        message: '',
      ),
      DataStatePresentation.unauthenticated => const _DataStateDefaults(
        icon: Icons.lock_outline_rounded,
        title: 'Sign in required',
        message: 'Sign in to access your data.',
      ),
      DataStatePresentation.failure => const _DataStateDefaults(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load data',
        message: 'Check your connection and try again.',
      ),
    };
  }
}

class _DataStateDefaults {
  const _DataStateDefaults({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;
}
