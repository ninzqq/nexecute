import 'package:flutter/material.dart';
import 'package:nexecute/models/tag.dart';

class TagListItem extends StatelessWidget {
  final Tag tag;
  const TagListItem({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blueGrey,
          border: Border.all(color: Colors.blueGrey),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(child: Text(tag.name)),
        ),
      ),
    );
  }
}
