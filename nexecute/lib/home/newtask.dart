import 'package:flutter/material.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:nexecute/services/services.dart';

class CreateNewTaskScreen extends StatelessWidget {
  const CreateNewTaskScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New execute'),
        backgroundColor: darkerCyan,
      ),
      body: Container(
        color: darkestCyan3,
        child: Center(
          child: FloatingActionButton(
            onPressed: () => {
              FirestoreService().addNewQuicxec("Jiihaaaa"),
            },
          ),
        ),
      ),
    );
  }
}
