import 'package:flutter/material.dart';
import 'package:nexecute/home/widgets/taglistitem.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/tag.dart';
import 'package:nexecute/themes.dart';

class NoteCardContent extends StatelessWidget {
  const NoteCardContent({
    super.key,
    required this.note,
    required this.onChecklistItemChanged,
  });

  final Quicxec note;
  final void Function(NoteChecklistItem item, bool isChecked)
  onChecklistItemChanged;

  @override
  Widget build(BuildContext context) {
    final hasTitle = note.title.trim().isNotEmpty;
    final hasText = note.text.trim().isNotEmpty;
    final hasContent =
        note.isChecklist ? note.checklistItems.isNotEmpty : hasText;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasTitle)
          Text(
            note.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (hasTitle && hasContent) const SizedBox(height: 8),
        if (note.isChecklist)
          _ChecklistPreview(
            items: note.checklistItems,
            onChanged: onChecklistItemChanged,
          )
        else if (hasText)
          Text(
            note.text,
            style: Theme.of(context).textTheme.bodyLarge,
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
          ),
        if (note.tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                note.tags
                    .map(
                      (tag) => TagListItem(tag: Tag(name: tag), compact: true),
                    )
                    .toList(),
          ),
        ],
      ],
    );
  }
}

class _ChecklistPreview extends StatelessWidget {
  const _ChecklistPreview({required this.items, required this.onChanged});

  final List<NoteChecklistItem> items;
  final void Function(NoteChecklistItem item, bool isChecked) onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final visibleItems = items.take(5).toList();

    return Column(
      key: const Key('note-checklist-preview'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in visibleItems)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  key: ValueKey('preview-checkbox-${item.id}'),
                  value: item.isChecked,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: BorderSide(color: palette.primary, width: 1.4),
                  onChanged:
                      (value) => onChanged(item, value ?? item.isChecked),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    item.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      decoration:
                          item.isChecked ? TextDecoration.lineThrough : null,
                      color:
                          item.isChecked
                              ? palette.onSurface.withValues(alpha: 0.62)
                              : palette.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (items.length > visibleItems.length)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, left: 32),
              child: Text(
                '+${items.length - visibleItems.length} more',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: palette.secondary),
              ),
            ),
          ),
      ],
    );
  }
}
