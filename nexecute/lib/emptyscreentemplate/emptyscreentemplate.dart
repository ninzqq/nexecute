import 'package:flutter/material.dart';

class EmptyScreenTemplate extends StatelessWidget {
  const EmptyScreenTemplate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: const Center(child: Text('Jaahas.')),
    );
  }
}
