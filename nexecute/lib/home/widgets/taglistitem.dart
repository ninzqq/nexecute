import 'package:flutter/material.dart';
import 'package:nexecute/models/tag.dart';
import 'package:nexecute/themes.dart';

class TagListItem extends StatelessWidget {
  final Tag tag;
  final bool isSelected;
  final bool compact;
  const TagListItem({
    super.key,
    required this.tag,
    this.isSelected = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 3),
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
            padding:
                compact
                    ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                    : const EdgeInsets.all(8),
            child: Center(
              child: Text(
                tag.name,
                style: compact ? Theme.of(context).textTheme.labelSmall : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
