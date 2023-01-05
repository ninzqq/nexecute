import 'package:flutter/material.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:nexecute/services/services.dart';
import 'package:nexecute/home/home.dart';
import 'package:provider/provider.dart';
import 'package:nexecute/buttons/emtpytrashpermanentlybutton.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var allQuicxecs = context.watch<List<Quicxec>>();
    var trashedQuicxecs = [];
    for (var q in allQuicxecs) {
      if (q.trashed) {
        trashedQuicxecs.add(q);
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trashed quicxecs'),
        backgroundColor: appBarDarkCyan,
        actions: const [
          EmptyTrashPermanentlyButton(),
        ],
      ),
      body: Container(
        color: bgDarkerCyan,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 120,
          ),
          itemCount: trashedQuicxecs.length,
          itemBuilder: (context, index) {
            var quicxec = trashedQuicxecs[index];
            return QuicxecItem(
              quicxec: Quicxec(
                  id: quicxec.id, text: quicxec.text, title: quicxec.title),
            );
          },
        ),
      ),
    );
  }
}
