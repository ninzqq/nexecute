import 'package:flutter/material.dart';
import 'package:nexecute/home/bottomsheets/delete_button.dart';
import 'package:nexecute/home/bottomsheets/item_type.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/quicxec.dart';

class ItemEditorHeader extends StatelessWidget {
  const ItemEditorHeader({
    super.key,
    required this.title,
    required this.type,
    required this.onTypeChanged,
    this.event,
    this.note,
  });

  final String title;
  final ItemType type;
  final ValueChanged<ItemType> onTypeChanged;
  final Event? event;
  final Quicxec? note;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showIcons = constraints.maxWidth >= 440;
        final selector = SegmentedButton<ItemType>(
          segments: [
            ButtonSegment(
              value: ItemType.event,
              label: const Text('Event'),
              icon: showIcons ? const Icon(Icons.event) : null,
            ),
            ButtonSegment(
              value: ItemType.quicxec,
              label: const Text('Note'),
              icon: showIcons ? const Icon(Icons.note) : null,
            ),
          ],
          selected: {type},
          onSelectionChanged: (selection) => onTypeChanged(selection.first),
        );
        final hasExistingItem =
            event?.id.isNotEmpty == true || note?.id.isNotEmpty == true;
        final titleRow = Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            if (hasExistingItem) ...[
              const SizedBox(width: 8),
              DeleteButton(quicxec: note, event: event),
            ],
          ],
        );

        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleRow,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: selector),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: titleRow),
            const SizedBox(width: 20),
            selector,
          ],
        );
      },
    );
  }
}
