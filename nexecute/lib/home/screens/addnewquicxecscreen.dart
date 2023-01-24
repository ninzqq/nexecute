import 'package:flutter/material.dart';
import 'package:nexecute/home/widgets/quicxecinputfields.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:nexecute/services/services.dart';

class AddNewQuicxecScreen extends StatelessWidget {
  const AddNewQuicxecScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textController = TextEditingController();
    final titleController = TextEditingController();
    var f = FocusNode();
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
                      else
                        {
                          FirestoreService().addNewQuicxec(
                              textController.text, titleController.text, []),
                        }
                    };
            },
            child: QuicxecInputFields(
              quicxec: Quicxec(id: '', text: ''),
              titleController: titleController,
              textController: textController,
              autofocus: true,
            ),
          ),
        ),
      ),
    );
  }
}
