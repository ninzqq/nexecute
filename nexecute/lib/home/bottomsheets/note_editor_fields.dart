import 'package:flutter/material.dart';
import 'package:nexecute/home/widgets/note_checklist_editor.dart';
import 'package:nexecute/models/quicxec.dart';

class NoteEditorFields extends StatelessWidget {
  const NoteEditorFields({
    super.key,
    required this.contentType,
    required this.descriptionController,
    this.descriptionHeight,
    required this.checklistItems,
    required this.onContentTypeChanged,
    required this.onChecklistItemChanged,
    required this.onChecklistItemRemoved,
    required this.onChecklistItemAdded,
  });

  final NoteContentType contentType;
  final TextEditingController descriptionController;
  final double? descriptionHeight;
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
        Row(
          children: [
            Text('Note format', style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            SegmentedButton<NoteContentType>(
              key: const Key('note-format-selector'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: NoteContentType.text,
                  label: Text('Text'),
                  icon: Icon(Icons.subject_rounded),
                ),
                ButtonSegment(
                  value: NoteContentType.checklist,
                  label: Text('Checklist'),
                  icon: Icon(Icons.checklist_rounded),
                ),
              ],
              selected: {contentType},
              onSelectionChanged:
                  (selection) => onContentTypeChanged(selection.first),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
