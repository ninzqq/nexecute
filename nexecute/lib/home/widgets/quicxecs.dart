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
    double baseScaleFactor = 1.0;
    double scaleFactor = 1.0;
    var allQuicxecs = context.watch<List<Quicxec>>();
    var activeQuicxecs = [];
    for (var q in allQuicxecs) {
      if (!q.trashed) {
        activeQuicxecs.add(q);
      }
    }
    return GestureDetector(
      onScaleStart: (details) => {
        baseScaleFactor = columnCount.columns.toDouble(),
      },
      onScaleUpdate: (details) => {
        scaleFactor = baseScaleFactor * details.scale,
        if (scaleFactor < 1)
          {scaleFactor = 1.0}
        else if (scaleFactor > 4)
          {scaleFactor = 4},
        columnCount.columns = scaleFactor.round(),
      },
      child: Container(
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
                  id: quicxec.id, text: quicxec.text, title: quicxec.title),
            );
          },
        ),
      ),
    );
  }
}
