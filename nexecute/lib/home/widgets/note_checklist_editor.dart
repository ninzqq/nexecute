import 'package:flutter/material.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/themes.dart';

class NoteChecklistEditor extends StatefulWidget {
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
  State<NoteChecklistEditor> createState() => _NoteChecklistEditorState();
}

class _NoteChecklistEditorState extends State<NoteChecklistEditor> {
  final Map<String, FocusNode> _itemFocusNodes = {};
  late Set<String> _knownItemIds;

  @override
  void initState() {
    super.initState();
    _knownItemIds = widget.items.map((item) => item.id).toSet();
    for (final id in _knownItemIds) {
      _itemFocusNodes[id] = FocusNode();
    }
  }

  @override
  void didUpdateWidget(NoteChecklistEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIds = widget.items.map((item) => item.id).toSet();
    final addedIds = currentIds.difference(_knownItemIds);
    final removedIds = _knownItemIds.difference(currentIds);

    for (final id in addedIds) {
      _itemFocusNodes[id] = FocusNode();
    }
    for (final id in removedIds) {
      _itemFocusNodes.remove(id)?.dispose();
    }
    _knownItemIds = currentIds;

    if (addedIds.isNotEmpty) {
      final itemToFocus = widget.items.lastWhere(
        (item) => addedIds.contains(item.id),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !widget.items.any((item) => item.id == itemToFocus.id)) {
          return;
        }
        _itemFocusNodes[itemToFocus.id]?.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final focusNode in _itemFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

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
          for (final item in widget.items)
            _ChecklistEditorRow(
              key: ValueKey('checklist-editor-row-${item.id}'),
              item: item,
              focusNode: _itemFocusNodes[item.id]!,
              onChanged: widget.onItemChanged,
              onRemoved: () => widget.onItemRemoved(item.id),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('add-checklist-item'),
              onPressed: widget.onItemAdded,
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
    required this.focusNode,
    required this.onChanged,
    required this.onRemoved,
  });

  final NoteChecklistItem item;
  final FocusNode focusNode;
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
            focusNode: focusNode,
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
