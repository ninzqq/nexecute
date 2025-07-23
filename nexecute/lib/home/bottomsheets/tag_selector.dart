import 'package:flutter/material.dart';
import 'package:nexecute/home/widgets/taglistitem.dart';
import 'package:nexecute/models/tag.dart';

class TagSelector extends StatelessWidget {
  final List<String> tags;
  final List<String> selectedTags;
  final ValueChanged<String> onTagToggled;

  const TagSelector({
    super.key,
    required this.tags,
    required this.selectedTags,
    required this.onTagToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blueGrey),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8.0),
        itemCount: tags.length,
        itemBuilder: (context, index) {
          final tag = tags[index];
          return GestureDetector(
            onTap: () => onTagToggled(tag),
            child: TagListItem(
              tag: Tag(name: tag),
              isSelected: selectedTags.contains(tag),
            ),
          );
        },
      ),
    );
  }
}
