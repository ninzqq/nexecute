import 'package:flutter/material.dart';
import 'package:nexecute/home/bottomsheets/delete_button.dart';
import 'package:nexecute/home/bottomsheets/item_type.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/quicxec.dart';

class ItemEditorHeader extends StatelessWidget {
  const ItemEditorHeader({
    super.key,
    required this.type,
    required this.onTypeChanged,
    this.event,
    this.note,
  });

  final ItemType type;
  final ValueChanged<ItemType> onTypeChanged;
  final Event? event;
  final Quicxec? note;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showIcons = constraints.maxWidth >= 440;
        return Row(
          children: [
            DeleteButton(quicxec: note, event: event),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: SegmentedButton<ItemType>(
                  segments: [
                    ButtonSegment(
                      value: ItemType.event,
                      label: const Text('Event'),
                      icon: showIcons ? const Icon(Icons.event) : null,
                    ),
                    ButtonSegment(
                      value: ItemType.quicxec,
                      label: const Text('Quicxec'),
                      icon: showIcons ? const Icon(Icons.note) : null,
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged:
                      (selection) => onTypeChanged(selection.first),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
