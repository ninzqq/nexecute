import 'package:flutter/material.dart';
import 'package:nexecute/services/services.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:provider/provider.dart';
import 'package:nexecute/home/widgets/quicxecitem.dart';

class Quicxecs extends StatelessWidget {
  const Quicxecs({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var columnCount = context.watch<QuicxecsColumnCount>();
    var allQuicxecs = context.watch<List<Quicxec>>();
    var activeQuicxecs = []; // Meaning: trashed=false
    for (var q in allQuicxecs) {
      if (!q.trashed) {
        activeQuicxecs.add(q);
      }
    }

    return Container(
      color: bgDarkerCyan,
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnCount.columns,
          mainAxisExtent: 120,
        ),
        itemCount: activeQuicxecs.length,
        itemBuilder: (context, index) {
          var quicxec = activeQuicxecs[index];
          return QuicxecItem(
            quicxec: Quicxec(
              id: quicxec.id,
              text: quicxec.text,
              title: quicxec.title,
              trashed: quicxec.trashed,
              tags: quicxec.tags,
            ),
          );
        },
      ),
    );
  }
}
