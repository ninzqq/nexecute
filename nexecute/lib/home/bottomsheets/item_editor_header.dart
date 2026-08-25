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
    return Row(
      children: [
        DeleteButton(quicxec: note, event: event),
        const Spacer(),
        SegmentedButton<ItemType>(
          segments: const [
            ButtonSegment(
              value: ItemType.event,
              label: Text('Event'),
              icon: Icon(Icons.event),
            ),
            ButtonSegment(
              value: ItemType.quicxec,
              label: Text('Quicxec'),
              icon: Icon(Icons.note),
            ),
          ],
          selected: {type},
          onSelectionChanged: (selection) => onTypeChanged(selection.first),
        ),
      ],
    );
  }
}
