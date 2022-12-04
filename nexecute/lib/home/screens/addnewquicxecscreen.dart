import 'package:flutter/material.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:nexecute/services/services.dart';

class AddNewQuicxecScreen extends StatelessWidget {
  const AddNewQuicxecScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final _controller = TextEditingController();
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
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.multiline,
              maxLines: null,
              expands: true,
              keyboardAppearance: Brightness.dark,
            ),
            autofocus: true,
            onFocusChange: (hasFocus) {
              hasFocus
                  ? () => {}
                  : {
                      if (_controller.text == '' || _controller.text.isEmpty)
                        {}
                      else
                        {
                          FirestoreService().addNewQuicxec(_controller.text),
                          FirestoreService().getQuicxecs(),
                        }
                    };
            },
          ),
        ),
      ),
    );
  }
}
