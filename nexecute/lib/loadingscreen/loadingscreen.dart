import 'package:flutter/material.dart';
import 'package:nexecute/shared/shared.dart';

class LoadingTextScreen extends StatelessWidget {
  const LoadingTextScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(''), backgroundColor: appBarDarkCyan),
      body: Container(
        color: bgDarkCyan,
        child: const Center(child: Text('LATAAING...', style: loadingText)),
      ),
    );
  }
}
