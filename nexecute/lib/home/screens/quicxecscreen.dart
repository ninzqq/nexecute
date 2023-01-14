import 'package:flutter/material.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:nexecute/services/services.dart';

class QuicxecScreen extends StatelessWidget {
  final Quicxec quicxec;
  const QuicxecScreen({Key? key, required this.quicxec}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final titleController = TextEditingController();
    final textController = TextEditingController();
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: appBarDarkCyan,
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: snackBarBgColor,
                  content: Text('Quicxec moved to trash'),
                ),
              );
              FirestoreService().moveCurrentlyOpenQuicxec(quicxec);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_outlined),
            tooltip: 'Move quicxec to trash',
          )
        ],
      ),
      body: Container(
        color: bgDarkCyan,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Focus(
            autofocus: false,
            onFocusChange: (hasFocus) {
              hasFocus
                  ? () => {}
                  : {
                      if (textController.text.isEmpty &&
                          titleController.text.isEmpty)
                        {
                          () => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: snackBarBgColor,
                                  content: Text('Empty quicxec discarded'),
                                ),
                              ),
                        }
                      else if ((textController.text != quicxec.text) ||
                          (titleController.text != quicxec.text))
                        {
                          FirestoreService().modifyCurrentlyOpenQuicxec(quicxec,
                              textController.text, titleController.text),
                        }
                      else
                        {
                          () => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: snackBarBgColor,
                                  content: Text('Unknown errorrrrrrrr...'),
                                ),
                              ),
                        }
                    };
            },
            child: Column(
              children: [
                TextField(
                  controller: titleController..text = quicxec.title,
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
                    padding: const EdgeInsets.only(top: 20.0),
                    child: TextField(
                      controller: textController..text = quicxec.text,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      expands: true,
                      keyboardAppearance: Brightness.dark,
                      style: quicxecText,
                      decoration:
                          const InputDecoration.collapsed(hintText: 'Quicxec'),
                    ),
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
