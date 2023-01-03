import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nexecute/loadingscreen/loadingscreen.dart';
import 'package:nexecute/services/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:provider/provider.dart';
import 'package:nexecute/home/widgets/quicxecitem.dart';

class Quicxecs extends StatelessWidget {
  Quicxecs({Key? key}) : super(key: key);

  final quicxecsStream = AuthService().userStream.switchMap(
        (user) => FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('quicxecs')
            .snapshots(),
      );

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
