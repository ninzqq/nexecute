import 'package:flutter/material.dart';
import 'package:nexecute/home/widgets/note_checklist_editor.dart';
import 'package:nexecute/models/quicxec.dart';

class NoteEditorFields extends StatelessWidget {
  const NoteEditorFields({
    super.key,
    required this.contentType,
    required this.descriptionController,
    this.descriptionHeight,
    this.compactPresentation = false,
    required this.checklistItems,
    required this.onContentTypeChanged,
    required this.onChecklistItemChanged,
    required this.onChecklistItemRemoved,
    required this.onChecklistItemAdded,
  });

  final NoteContentType contentType;
  final TextEditingController descriptionController;
  final double? descriptionHeight;
  final bool compactPresentation;
  final List<NoteChecklistItem> checklistItems;
  final ValueChanged<NoteContentType> onContentTypeChanged;
  final ValueChanged<NoteChecklistItem> onChecklistItemChanged;
  final ValueChanged<String> onChecklistItemRemoved;
  final VoidCallback onChecklistItemAdded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = compactPresentation || constraints.maxWidth < 440;
            final selector = SegmentedButton<NoteContentType>(
              key: const Key('note-format-selector'),
              showSelectedIcon: false,
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
                  value: NoteContentType.text,
                  label: const Text('Text'),
                  icon: compact ? null : const Icon(Icons.subject_rounded),
                ),
                ButtonSegment(
                  value: NoteContentType.checklist,
                  label: const Text('Checklist'),
                  icon: compact ? null : const Icon(Icons.checklist_rounded),
                ),
              ],
              selected: {contentType},
              onSelectionChanged:
                  (selection) => onContentTypeChanged(selection.first),
            );
            final label = Text(
              'Note format',
              style: Theme.of(context).textTheme.labelLarge,
            );
            if (compactPresentation) {
              return Align(alignment: Alignment.centerRight, child: selector);
            }
            return compact
                ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    label,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: selector),
                  ],
                )
                : Row(children: [label, const Spacer(), selector]);
          },
        ),
        SizedBox(height: compactPresentation ? 8 : 12),
        if (contentType == NoteContentType.checklist)
          NoteChecklistEditor(
            items: checklistItems,
            onItemChanged: onChecklistItemChanged,
            onItemRemoved: onChecklistItemRemoved,
            onItemAdded: onChecklistItemAdded,
          )
        else
          SizedBox(
            height: descriptionHeight,
            child: TextFormField(
              key: const Key('note-description-field'),
              controller: descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              minLines: descriptionHeight == null ? 6 : null,
              maxLines: descriptionHeight == null ? 18 : null,
              expands: descriptionHeight != null,
            ),
          ),
      ],
    );
  }
}
