import 'package:flutter/material.dart';
import 'package:nexecute/loadingscreen/loadingscreen.dart';
import 'package:nexecute/services/services.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:provider/provider.dart';
import 'package:nexecute/home/widgets/quicxecitem.dart';

class Quicxecs extends StatelessWidget {
  const Quicxecs({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var quicxecs = context.watch<QuicxecsList>();

    return FutureBuilder<QuicxecsList>(
      future: FirestoreService().getQuicxecs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingTextScreen();
        } else if (snapshot.hasError) {
          return Center(
            child: ErrorMessage(message: snapshot.error.toString()),
          );
        } else if (snapshot.hasData) {
          quicxecs = snapshot.data!;

          return Container(
            color: bgDarkerCyan,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
              ),
              itemCount: quicxecs.quicxecs.length,
              itemBuilder: (context, index) {
                return QuicxecItem(quicxec: quicxecs.quicxecs[index]);
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
