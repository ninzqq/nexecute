import 'package:flutter/material.dart';
import 'package:nexecute/home/home.dart';
import 'package:provider/provider.dart';
import 'package:nexecute/buttons/emtpytrashpermanentlybutton.dart';
import 'package:nexecute/models/quicxec.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

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
        actions: const [EmptyTrashPermanentlyButton()],
      ),
      body: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 120,
        ),
        itemCount: trashedQuicxecs.length,
        itemBuilder: (context, index) {
          var quicxec = trashedQuicxecs[index];
          return QuicxecItem(
            quicxec: Quicxec(
              id: quicxec.id,
              text: quicxec.text,
              title: quicxec.title,
              trashed: quicxec.trashed,
              tags: quicxec.tags,
              created: quicxec.created,
              contentType: quicxec.contentType,
              checklistItems: quicxec.checklistItems,
            ),
          );
        },
      ),
    );
  }
}
