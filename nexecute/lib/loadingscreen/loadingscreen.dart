import 'package:flutter/material.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:nexecute/services/services.dart';

class LoadingTextScreen extends StatelessWidget {
  const LoadingTextScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: appBarDarkCyan,
      ),
      body: Container(
        color: bgDarkCyan,
        child: const Center(
          child: Text(
            'LATAAING...',
            style: loadingText,
          ),
        ),
      ),
    );
  }
}
