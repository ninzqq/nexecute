import 'package:flutter/material.dart';
import 'package:nexecute/services/services.dart';
import 'package:nexecute/home/home.dart';
import 'package:nexecute/shared/shared.dart';

class QuicxecItem extends StatelessWidget {
  final Quicxec quicxec;
  const QuicxecItem({Key? key, required this.quicxec}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        showMenu(
          context: context,
          position: const RelativeRect.fromLTRB(5.0, 111.0, 0.0, 0.0),
          items: <PopupMenuEntry>[
            const PopupMenuItem<String>(
              padding: EdgeInsets.symmetric(vertical: 0, horizontal: 6),
              enabled: true,
              value: '',
              child: Text('TRAAAASH'),
            ),
          ],
        );
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
                      QuicxecScreen(quicxec: quicxec),
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
