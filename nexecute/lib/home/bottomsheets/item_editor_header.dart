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
    this.onNoteArchived,
    this.compactPresentation = false,
  });

  final String title;
  final ItemType type;
  final ValueChanged<ItemType> onTypeChanged;
  final Event? event;
  final Quicxec? note;
  final VoidCallback? onNoteArchived;
  final bool compactPresentation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showIcons = !compactPresentation && constraints.maxWidth >= 440;
        final selector = SegmentedButton<ItemType>(
          style:
              compactPresentation
                  ? const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    minimumSize: WidgetStatePropertyAll(Size(0, 36)),
                    padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 8),
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )
                  : null,
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
              child: Text(
                title,
                style:
                    compactPresentation
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (hasExistingItem) ...[
              const SizedBox(width: 8),
              DeleteButton(
                quicxec: note,
                event: event,
                onNoteArchived: onNoteArchived,
              ),
            ],
          ],
        );

        if (!compactPresentation && constraints.maxWidth < 520) {
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
            SizedBox(width: compactPresentation ? 8 : 20),
            selector,
          ],
        );
      },
    );
  }
}
