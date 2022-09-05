import 'package:flutter/material.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:nexecute/services/services.dart';

class EmptyScreenTemplate extends StatelessWidget {
  const EmptyScreenTemplate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: darkerCyan,
      ),
      body: Container(
        color: darkestCyan3,
        child: const Center(
          child: Text('Jaahas.'),
        ),
      ),
    );
  }
}
