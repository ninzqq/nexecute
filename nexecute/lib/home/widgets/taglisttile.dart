import 'package:flutter/material.dart';
import 'package:nexecute/services/firestore.dart';

import '../../shared/shared.dart';

class TagListTile extends StatelessWidget {
  final String tag;
  const TagListTile({super.key, required this.tag});

  _onLongPress(LongPressStartDetails details, context) {
    showMenu(
      color: darkCyan,
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
          details.globalPosition.dx,
          details.globalPosition.dy,
          1,
          1,
        ),
        const Rect.fromLTWH(0, 0, 1000, 1000),
      ),
      items: [
        PopupMenuItem(
          onTap: () {
            FirestoreService().removeSelectedTag(tag);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: snackBarBgColor,
                content: Text('Tag deleted'),
              ),
            );
          },
          child: const Text('Delete tag'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) {
        _onLongPress(details, context);
      },
      child: ListTile(
        dense: true,
        title: Text(tag, style: const TextStyle(fontSize: 16)),
        trailing: IconButton(
          onPressed: () {
            FirestoreService().removeSelectedTag(tag);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: snackBarBgColor,
                content: Text('Tag deleted'),
              ),
            );
          },
          icon: Icon(Icons.delete, color: Colors.white70),
        ),
      ),
    );
  }
}
