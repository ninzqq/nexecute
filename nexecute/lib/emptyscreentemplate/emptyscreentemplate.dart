import 'package:flutter/material.dart';
import 'package:nexecute/shared/shared.dart';

class EmptyScreenTemplate extends StatelessWidget {
  const EmptyScreenTemplate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(''), backgroundColor: appBarDarkCyan),
      body: Container(
        color: bgDarkCyan,
        child: const Center(child: Text('Jaahas.')),
      ),
    );
  }
}
