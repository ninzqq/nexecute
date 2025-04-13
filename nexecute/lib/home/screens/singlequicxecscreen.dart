import 'package:flutter/material.dart';
import 'package:nexecute/home/widgets/quicxecinputfields.dart';
import 'package:nexecute/shared/bottommenubar.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:nexecute/services/services.dart';
import 'package:nexecute/models/quicxec.dart';

class SingleQuicxecScreen extends StatelessWidget {
  final Quicxec quicxec;
  const SingleQuicxecScreen({super.key, required this.quicxec});

  @override
  Widget build(BuildContext context) {
    final titleController = TextEditingController();
    final textController = TextEditingController();
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: appBarDarkCyan,
        actions: [
          !quicxec.trashed
              ? IconButton(
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
              : IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: snackBarBgColor,
                        content: Text('Quicxec restored'),
                      ),
                    );
                    FirestoreService().moveCurrentlyOpenQuicxec(quicxec);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.restore_from_trash_rounded),
                  tooltip: 'Restore quicxec',
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
                          FirestoreService().modifyCurrentlyOpenQuicxec(
                            quicxec,
                            textController.text,
                            titleController.text,
                            quicxec.tags,
                          ),
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
            child: QuicxecInputFields(
              quicxec: quicxec,
              titleController: titleController,
              textController: textController,
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: MediaQuery.of(context)
            .viewInsets, // This is to make the app bar float on top of keyboard
        child: BottomMenubar(
          quicxec: quicxec,
        ),
      ),
    );
  }
}
