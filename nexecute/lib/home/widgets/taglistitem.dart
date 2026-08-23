import 'package:flutter/material.dart';
import 'package:nexecute/models/tag.dart';
import 'package:nexecute/themes.dart';

class TagListItem extends StatelessWidget {
  final Tag tag;
  final bool isSelected;
  const TagListItem({super.key, required this.tag, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3.0),
      child: InkWell(
        child: Container(
          decoration: BoxDecoration(
            color:
                isSelected
                    ? palette.success.withValues(alpha: 0.35)
                    : palette.surfaceRaised,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(child: Text(tag.name)),
          ),
        ),
      ),
    );
  }
}
