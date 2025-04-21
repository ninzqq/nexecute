import 'package:flutter/material.dart';
import 'package:nexecute/home/bottomsheets/item_editor.dart';
import 'package:nexecute/home/widgets/taglistitem.dart';
import 'package:nexecute/models/tag.dart';
import 'package:nexecute/services/services.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:nexecute/models/quicxec.dart';

class QuicxecItem extends StatelessWidget {
  final Quicxec quicxec;
  const QuicxecItem({super.key, required this.quicxec});

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
            FirestoreService().moveCurrentlyOpenQuicxec(quicxec);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: snackBarBgColor,
                content: Text('Quicxec moved to trash'),
              ),
            );
          },
          child:
              quicxec.trashed
                  ? const Text('Restore')
                  : const Text('Move to trash'),
        ),
        if (quicxec.trashed)
          PopupMenuItem(
            onTap: () {
              FirestoreService().permanentlyDeleteSingleQuicxec(quicxec);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: snackBarBgColor,
                  content: Text('Quicxec deleted.'),
                ),
              );
            },
            child: const Text('Delete permanently'),
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
      child: Hero(
        tag: quicxec.id,
        child: Card(
          clipBehavior: Clip.antiAlias,
          color: bgDarkCyan,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.cyan.shade100),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: InkWell(
            onTap: () {
              showItemEditor(context, quicxec: quicxec, isEditing: true);
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(quicxec.title, style: quicxecTitleText),
                  Expanded(child: Text(quicxec.text, style: quicxecText)),
                  SizedBox(
                    height: 20,
                    child: Row(
                      children: [
                        Flexible(
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: quicxec.tags.length,
                            itemBuilder: (BuildContext context, int index) {
                              return TagListItem(
                                tag: Tag(name: quicxec.tags[index]),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
