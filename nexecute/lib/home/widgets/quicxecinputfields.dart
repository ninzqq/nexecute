import 'package:flutter/material.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:nexecute/services/services.dart';

class QuicxecInputFields extends StatelessWidget {
  final Quicxec quicxec;
  final TextEditingController titleController;
  final TextEditingController textController;
  final bool? autofocus;

  const QuicxecInputFields({
    Key? key,
    required this.quicxec,
    required this.titleController,
    required this.textController,
    this.autofocus = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: titleController..text = quicxec.title,
          keyboardType: TextInputType.text,
          maxLines: 1,
          expands: false,
          keyboardAppearance: Brightness.dark,
          style: quicxecTitleText,
          decoration: const InputDecoration.collapsed(hintText: 'Title'),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: TextField(
              controller: textController..text = quicxec.text,
              keyboardType: TextInputType.multiline,
              maxLines: null,
              expands: true,
              autofocus: autofocus as bool,
              keyboardAppearance: Brightness.dark,
              style: quicxecText,
              decoration: const InputDecoration.collapsed(hintText: 'Quicxec'),
            ),
          ),
        ),
      ],
    );
  }
}
