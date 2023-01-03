import 'package:flutter/material.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:nexecute/services/services.dart';

class QuicxecScreen extends StatelessWidget {
  final Quicxec quicxec;
  const QuicxecScreen({Key? key, required this.quicxec}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return Hero(
      tag: quicxec.id,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(''),
          backgroundColor: appBarDarkCyan,
          actions: [
            IconButton(
              onPressed: () {
                FirestoreService().moveCurrentlyOpenQuicxecToTrash(quicxec);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_forever_rounded),
            )
          ],
        ),
        body: Container(
          color: bgDarkCyan,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Focus(
              autofocus: false,
              onFocusChange: (hasFocus) {
                hasFocus
                    ? () => {}
                    : {
                        if (controller.text == '' || controller.text.isEmpty)
                          {}
                        else if (controller.text != quicxec.text)
                          {
                            FirestoreService().modifyCurrentlyOpenQuicxec(
                                quicxec, controller.text),
                          }
                        else
                          {}
                      };
              },
              child: TextField(
                controller: controller..text = quicxec.text,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                expands: true,
                keyboardAppearance: Brightness.dark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
