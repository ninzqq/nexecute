import 'package:flutter/material.dart';
import 'package:nexecute/models/event.dart';

class SingleEventMarkerWidget extends StatelessWidget {
  final Event event;
  const SingleEventMarkerWidget({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 16,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withAlpha(80),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          event.title,
          style: theme.textTheme.bodySmall!.copyWith(fontSize: 10),
        ),
      ),
    );
  }
}
