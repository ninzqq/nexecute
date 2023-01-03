import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nexecute/loadingscreen/loadingscreen.dart';
import 'package:nexecute/services/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:provider/provider.dart';
import 'package:nexecute/home/widgets/quicxecitem.dart';

// Stateful widget used here in order to prevent initializing the stream
// more than once in the beginning, by placing the stream initialization
// inside initState.
// This is due to decreasing the amount
// of reads from Firestore.

//class Quicxecs extends StatefulWidget {
//  const Quicxecs({Key? key}) : super(key: key);
//  @override
//  QuicxecsState createState() => QuicxecsState();
//}

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
            quicxec: Quicxec(id: doc.id, text: doc.text),
          );
        },
      ),
    );
  }
}
