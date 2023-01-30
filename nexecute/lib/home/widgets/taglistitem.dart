import 'package:flutter/material.dart';

class TagListItem extends StatelessWidget {
  final String tagText;
  const TagListItem({
    Key? key,
    required this.tagText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blueGrey),
          borderRadius: const BorderRadius.all(
            Radius.circular(10),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 2, left: 4, right: 4),
          child: Text(tagText),
        ),
      ),
    );
  }
}
