import 'package:flutter/material.dart';

class TagListItem extends StatelessWidget {
  final String tagText;
  const TagListItem({
    Key? key,
    required this.tagText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueGrey),
        borderRadius: const BorderRadius.all(
          Radius.circular(10),
        ),
      ),
      child: Text(tagText),
    );
  }
}
