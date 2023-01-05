import 'package:flutter/material.dart';
import 'package:nexecute/services/services.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:provider/provider.dart';
import 'package:nexecute/home/widgets/quicxecitem.dart';

class Quicxecs extends StatelessWidget {
  const Quicxecs({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var qs = context.watch<List<Quicxec>>();
    return Container(
      color: bgDarkerCyan,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 120,
        ),
        itemCount: qs.length,
        itemBuilder: (context, index) {
          var doc = qs[index];
          return QuicxecItem(
            quicxec: Quicxec(id: doc.id, text: doc.text, title: doc.title),
          );
        },
      ),
    );
  }
}
