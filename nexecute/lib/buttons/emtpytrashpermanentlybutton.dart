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
                                context.read<NoteRepository>().emptyTrash(),
                                Navigator.pop(context, 'Yes'),
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Trash emptied'),
                                  ),
                                ),
                              },
                          child: const Text('Yes'),
                        ),
                      ],
                    ),
              )
              : null,
      icon: const Icon(Icons.delete_forever),
      tooltip: 'Empty trash permanently',
    );
  }
}
