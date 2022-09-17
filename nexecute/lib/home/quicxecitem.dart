import 'package:flutter/material.dart';
import 'package:nexecute/services/services.dart';
import 'package:nexecute/shared/shared.dart';

class QuicxecItem extends StatelessWidget {
  final Quicxec quicxec;
  const QuicxecItem({Key? key, required this.quicxec}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        color: bgDarkCyan,
        child: Text(quicxec.title),
      ),
    );
  }
}
