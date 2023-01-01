import 'package:flutter/material.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:nexecute/services/services.dart';

class AddNewQuicxecScreen extends StatelessWidget {
  const AddNewQuicxecScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return Scaffold(
      appBar: AppBar(
        title: const Text('New execute'),
        backgroundColor: appBarDarkCyan,
      ),
      body: Container(
        color: bgDarkCyan,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Focus(
            autofocus: true,
            onFocusChange: (hasFocus) {
              hasFocus
                  ? () => {}
                  : {
                      if (controller.text == '' || controller.text.isEmpty)
                        {}
                      else
                        {
                          FirestoreService().addNewQuicxec(controller.text),
                        }
                    };
            },
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.multiline,
              maxLines: null,
              expands: true,
              keyboardAppearance: Brightness.dark,
            ),
          ),
        ),
      ),
    );
  }
}
