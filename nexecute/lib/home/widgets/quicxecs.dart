import 'package:cloud_firestore/cloud_firestore.dart';
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

class Quicxecs extends StatefulWidget {
  const Quicxecs({Key? key}) : super(key: key);
  @override
  QuicxecsState createState() => QuicxecsState();
}

class QuicxecsState extends State<Quicxecs> {
  dynamic quicxecsStream;
  @override
  void initState() {
    quicxecsStream = AuthService().userStream.switchMap(
          (user) => FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .collection('quicxecs')
              .snapshots(),
        );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: quicxecsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingTextScreen();
        } else if (snapshot.hasError) {
          return Center(
            child: ErrorMessage(message: snapshot.error.toString()),
          );
        } else if (snapshot.hasData) {
          return Container(
            color: bgDarkerCyan,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 120,
              ),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var doc = snapshot.data!.docs[index];
                var data = doc.data() as Map;

                return QuicxecItem(
                  quicxec: Quicxec(id: data['id'], text: data['text']),
                );
              },
            ),
          );
        } else {
          return const Center(
            child: Text('Unknown error, hehe.'),
          );
        }
      },
    );
  }
}
