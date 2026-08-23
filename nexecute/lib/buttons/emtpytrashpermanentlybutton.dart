import 'package:flutter/material.dart';
import 'package:nexecute/services/firestore.dart';

class EmptyTrashPermanentlyButton extends StatelessWidget {
  const EmptyTrashPermanentlyButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed:
          () => showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Warning'),
                  content: const Text(
                    'Are you sure you want to delete all the items in trash permanently?\nNote: This action cannot be undone.',
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'Cancel'),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed:
                          () => {
                            FirestoreService().emptyTrash(),
                            Navigator.pop(context, 'Yes'),
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Trash emptied')),
                            ),
                          },
                      child: const Text('Yes'),
                    ),
                  ],
                ),
          ),
      icon: const Icon(Icons.delete_forever),
      tooltip: 'Empty trash permanently',
    );
  }
}
