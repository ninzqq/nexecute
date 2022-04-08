import 'package:flutter/material.dart';
import 'package:nexecute/shared/shared.dart';

class CreateNewTaskScreen extends StatelessWidget {
  const CreateNewTaskScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New execute'),
        backgroundColor: darkestCyan,
      ),
      body: Container(
        color: darkestCyan3,
      ),
    );
  }
}
