import 'package:flutter/material.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:nexecute/services/services.dart';

class QuicxecScreen extends StatelessWidget {
  final Quicxec quicxec;
  const QuicxecScreen({Key? key, required this.quicxec}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: quicxec.id,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(''),
          backgroundColor: appBarDarkCyan,
          actions: [
            IconButton(
              onPressed: () {
                FirestoreService().removeCurrentlyOpenQuicxec(quicxec);
              },
              icon: const Icon(Icons.delete_forever_rounded),
            )
          ],
        ),
        body: Container(
          color: bgDarkCyan,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: TextField(
              controller: TextEditingController()..text = quicxec.title,
              keyboardType: TextInputType.multiline,
              maxLines: null,
              expands: true,
              keyboardAppearance: Brightness.dark,
            ),
          ),
        ),
      ),
    );
  }
}
