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
        backgroundColor: appBarDarkCyan,
      ),
      body: Container(
        color: bgDarkCyan,
        child: Center(
          child: Column(
            children: [
              FloatingActionButton(
                child: const Icon(Icons.add_rounded),
                backgroundColor: primaryButtonCyan,
                onPressed: () => {
                  FirestoreService().addNewQuicxec('asdasfd'),
                },
              ),
              FloatingActionButton(
                backgroundColor: primaryButtonCyan,
                onPressed: () => {
                  FirestoreService().getQuicxecs(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
