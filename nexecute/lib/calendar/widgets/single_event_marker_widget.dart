import 'package:flutter/material.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/shared/shared.dart';

class SingleEventMarkerWidget extends StatelessWidget {
  final Event event;
  const SingleEventMarkerWidget({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 1, left: 1, right: 1),
      child: SizedBox(
        height: 16,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: darkCyan,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            event.title,
            style: theme.textTheme.bodySmall!.copyWith(fontSize: 10),
          ),
        ),
      ),
    );
  }
}
