import 'package:flutter/material.dart';
import 'package:nexecute/services/services.dart';
import 'package:nexecute/shared/shared.dart';

class QuicxecItem extends StatelessWidget {
  final Quicxec quicxec;
  const QuicxecItem({Key? key, required this.quicxec}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Container(
        decoration: BoxDecoration(
            color: bgDarkCyan,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.cyan.shade100,
              width: 1,
            )),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(quicxec.title),
        ),
      ),
    );
  }
}
