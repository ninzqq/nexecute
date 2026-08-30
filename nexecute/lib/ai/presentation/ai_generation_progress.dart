import 'package:flutter/material.dart';

class AiGenerationProgress extends StatefulWidget {
  const AiGenerationProgress({
    super.key,
    required this.reasoning,
    required this.keyPrefix,
  });

  final String reasoning;
  final String keyPrefix;

  @override
  State<AiGenerationProgress> createState() => _AiGenerationProgressState();
}

class _AiGenerationProgressState extends State<AiGenerationProgress> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant AiGenerationProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reasoning != widget.reasoning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visibleReasoning = widget.reasoning.trim();

    return DecoratedBox(
      key: Key('${widget.keyPrefix}-progress'),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Generating proposal…',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (visibleReasoning.isEmpty)
              Text(
                'Waiting for the model to begin responding…',
                key: Key('${widget.keyPrefix}-waiting'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              )
            else ...[
              Text(
                'Reasoning · session only · not synchronized',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: Scrollbar(
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: SelectableText(
                      visibleReasoning,
                      key: Key('${widget.keyPrefix}-reasoning'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
