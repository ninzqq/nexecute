import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nexecute/home/widgets/quicxecitem.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/quicxec_column_count.dart';

class Quicxecs extends StatelessWidget {
  const Quicxecs({super.key});

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

    return Column(
      children: [
        SizedBox(height: 2),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnCount.columns,
                mainAxisExtent: 120,
                mainAxisSpacing: 1,
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
                    created: quicxec.created,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
