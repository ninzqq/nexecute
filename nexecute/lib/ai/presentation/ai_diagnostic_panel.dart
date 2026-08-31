import 'package:flutter/material.dart';
import 'package:nexecute/ai/domain/ai_diagnostic.dart';

/// A consistent, user-safe presentation for actionable AI failure guidance.
class AiDiagnosticPanel extends StatelessWidget {
  const AiDiagnosticPanel({
    super.key,
    required this.diagnostic,
    this.compact = false,
    this.actionLabel = 'Open AI Settings',
    this.onAction,
  });

  final AiDiagnostic diagnostic;
  final bool compact;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: '${diagnostic.title}. ${diagnostic.summary}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.errorContainer.withValues(alpha: 0.55),
          border: Border.all(color: colors.error.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 10 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, size: 20, color: colors.error),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diagnostic.title,
                      key: Key('ai-diagnostic-${diagnostic.code}'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colors.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      diagnostic.summary,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onErrorContainer,
                      ),
                    ),
                    if (diagnostic.suggestions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      for (final suggestion in diagnostic.suggestions)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '• $suggestion',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onErrorContainer),
                          ),
                        ),
                    ],
                    if (onAction != null) ...[
                      const SizedBox(height: 6),
                      TextButton.icon(
                        key: Key('ai-diagnostic-action-${diagnostic.code}'),
                        onPressed: onAction,
                        icon: const Icon(Icons.settings_outlined, size: 18),
                        label: Text(actionLabel),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
