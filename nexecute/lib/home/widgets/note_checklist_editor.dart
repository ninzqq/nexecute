import 'package:flutter/material.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/themes.dart';

class NoteChecklistEditor extends StatelessWidget {
  const NoteChecklistEditor({
    super.key,
    required this.items,
    required this.onItemChanged,
    required this.onItemRemoved,
    required this.onItemAdded,
  });

  final List<NoteChecklistItem> items;
  final ValueChanged<NoteChecklistItem> onItemChanged;
  final ValueChanged<String> onItemRemoved;
  final VoidCallback onItemAdded;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      key: const Key('note-checklist-editor'),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        border: Border.all(color: palette.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            _ChecklistEditorRow(
              key: ValueKey('checklist-editor-row-${item.id}'),
              item: item,
              onChanged: onItemChanged,
              onRemoved: () => onItemRemoved(item.id),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('add-checklist-item'),
              onPressed: onItemAdded,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add item'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistEditorRow extends StatelessWidget {
  const _ChecklistEditorRow({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onRemoved,
  });

  final NoteChecklistItem item;
  final ValueChanged<NoteChecklistItem> onChanged;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          key: ValueKey('checklist-checkbox-${item.id}'),
          value: item.isChecked,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          side: BorderSide(color: palette.primary, width: 1.5),
          onChanged:
              (value) => onChanged(item.copyWith(isChecked: value ?? false)),
        ),
        Expanded(
          child: TextFormField(
            key: ValueKey('checklist-text-${item.id}'),
            initialValue: item.text,
            maxLines: null,
            textInputAction: TextInputAction.next,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              decoration: item.isChecked ? TextDecoration.lineThrough : null,
            ),
            decoration: const InputDecoration(
              hintText: 'List item',
              border: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (text) => onChanged(item.copyWith(text: text)),
          ),
        ),
        IconButton(
          tooltip: 'Remove checklist item',
          visualDensity: VisualDensity.compact,
          onPressed: onRemoved,
          icon: const Icon(Icons.close_rounded, size: 18),
        ),
      ],
    );
  }
}
