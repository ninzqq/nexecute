import 'package:flutter/material.dart';
import 'package:nexecute/services/services.dart';
import 'package:nexecute/home/home.dart';
import 'package:nexecute/shared/shared.dart';

class QuicxecItem extends StatelessWidget {
  final Quicxec quicxec;
  const QuicxecItem({
    Key? key,
    required this.quicxec,
  }) : super(key: key);

  _onLongPress(LongPressStartDetails details, context) {
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: snackBarBgColor,
                content: Text('Quicxec moved to trash'),
              ),
            );
            FirestoreService().moveCurrentlyOpenQuicxec(quicxec);
          },
          child: quicxec.trashed
              ? const Text('Restore')
              : const Text('Move to trash'),
        )
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
            side: BorderSide(
              color: Colors.cyan.shade100,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (BuildContext context) =>
                      SingleQuicxecScreen(quicxec: quicxec),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quicxec.title,
                    style: quicxecTitleText,
                  ),
                  Expanded(
                      child: Text(
                    quicxec.text,
                    style: quicxecText,
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
