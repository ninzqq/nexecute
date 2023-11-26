import 'package:flutter/material.dart';
import 'package:nexecute/services/models.dart';
import 'package:nexecute/services/services.dart';
import 'package:nexecute/shared/shared.dart';
import '../home/widgets/taglistitem.dart';

class BottomMenubar extends StatelessWidget {
  final Quicxec quicxec;
  const BottomMenubar({
    Key? key,
    required this.quicxec,
  }) : super(key: key);

  _onPress(LongPressStartDetails details, context) {
    showMenu(
      color: darkCyan,
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
            details.globalPosition.dx, details.globalPosition.dy, 1, 1),
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
          child: quicxec.trashed
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
    final Size size = MediaQuery.of(context).size;
    const double navBarHeight = 65.0;

    return SizedBox(
      width: size.width,
      height: navBarHeight,
      child: Container(
        color: Colors.black26,
        child: Column(
          children: [
            SizedBox(
              height: 25,
              child: Padding(
                padding: const EdgeInsets.only(top: 5.0, left: 5.0),
                child: Row(
                  children: [
                    Flexible(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: quicxec.tags.length,
                        itemBuilder: (BuildContext context, int index) {
                          return TagListItem(tagText: quicxec.tags[index]);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: size.width,
              height: 35,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => {},
                    icon: const Icon(Icons.new_label_outlined),
                  ),
                  IconButton(
                    onPressed: () => {},
                    icon: const Icon(Icons.menu),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
