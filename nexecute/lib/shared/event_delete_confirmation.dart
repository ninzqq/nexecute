import 'package:flutter/material.dart';
import 'package:nexecute/models/event.dart';

Future<bool> confirmEventDeletion(BuildContext context, Event event) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: const Text('Delete event?'),
          content: Text(
            'Delete “${event.title}”? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
  );

  return confirmed == true;
}
