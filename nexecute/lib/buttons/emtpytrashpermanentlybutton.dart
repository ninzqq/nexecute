import 'package:flutter/material.dart';
import 'package:nexecute/repositories/note_repository.dart';
import 'package:provider/provider.dart';

class EmptyTrashPermanentlyButton extends StatelessWidget {
  const EmptyTrashPermanentlyButton({super.key, this.enabled = true});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed:
          enabled
              ? () => showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Delete all archived notes?'),
                      content: const Text(
                        'Every note in the archive will be permanently deleted. This action cannot be undone.',
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.pop(context, 'Cancel'),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed:
                              () => {
                                context.read<NoteRepository>().emptyTrash(),
                                Navigator.pop(context, 'Yes'),
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Archived notes deleted'),
                                  ),
                                ),
                              },
                          child: const Text('Delete all'),
                        ),
                      ],
                    ),
              )
              : null,
      icon: const Icon(Icons.delete_forever),
      tooltip: 'Delete all archived notes',
    );
  }
}
