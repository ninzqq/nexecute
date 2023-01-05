import 'package:flutter/material.dart';
import 'package:nexecute/services/firestore.dart';
import 'package:nexecute/shared/shared.dart';

class EmptyTrashPermanentlyButton extends StatelessWidget {
  const EmptyTrashPermanentlyButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Warning'),
                backgroundColor: darkGreen,
                content: const Text(
                    'Are you sure you want to delete all the items in trash permanently?\nNote: This action cannot be undone.'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'Cancel'),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => {
                      FirestoreService().emptyTrash(),
                      Navigator.pop(context, 'Yes'),
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: snackBarBgColor,
                          content: Text('Trash emptied'),
                        ),
                      ),
                    },
                    child: const Text('Yes'),
                  ),
                ],
              )),
      icon: const Icon(Icons.delete_forever),
      tooltip: 'Empty trash permanently',
    );
  }
}
