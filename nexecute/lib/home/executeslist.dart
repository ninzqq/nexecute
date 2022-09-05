import 'package:flutter/material.dart';
import 'package:nexecute/services/services.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:provider/provider.dart';

class ExecutesList extends StatelessWidget {
  const ExecutesList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var quicxecs = Provider.of<QuicxecsList>(context, listen: true);

    return Container(
      color: darkestCyan2,
      child: ListView.builder(
        itemCount: quicxecs.quicxecsList.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(5),
            child: ListTile(
              title: Text(quicxecs.quicxecsList[index].title),
            ),
          );
        },
      ),
    );
  }
}
