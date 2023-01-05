import 'package:flutter/material.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:nexecute/services/services.dart';

class AddNewQuicxecScreen extends StatelessWidget {
  const AddNewQuicxecScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textController = TextEditingController();
    final titleController = TextEditingController();
    return Scaffold(
      appBar: AppBar(
        title: const Text('New quicxec'),
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
                      if (textController.text == '' ||
                          textController.text.isEmpty)
                        {}
                      else
                        {
                          FirestoreService().addNewQuicxec(
                              textController.text, titleController.text),
                        }
                    };
            },
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  keyboardType: TextInputType.text,
                  maxLines: 1,
                  expands: false,
                  keyboardAppearance: Brightness.dark,
                  style: quicxecTitleText,
                  decoration:
                      const InputDecoration.collapsed(hintText: 'Title'),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 15),
                    child: TextField(
                        controller: textController,
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        expands: true,
                        keyboardAppearance: Brightness.dark,
                        style: quicxecText,
                        decoration: const InputDecoration.collapsed(
                            hintText: 'Quicxec')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
