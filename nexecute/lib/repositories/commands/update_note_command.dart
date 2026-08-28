import 'package:nexecute/models/quicxec.dart';

class UpdateNoteCommand {
  UpdateNoteCommand({
    required this.noteId,
    required this.text,
    required this.title,
    required this.folderId,
    required List<String> tags,
    required this.contentType,
    required List<NoteChecklistItem> checklistItems,
  }) : tags = List.unmodifiable(tags),
       checklistItems = List.unmodifiable(checklistItems);

  factory UpdateNoteCommand.fromNote(Quicxec note) {
    return UpdateNoteCommand(
      noteId: note.id,
      text: note.text,
      title: note.title,
      folderId: note.folderId,
      tags: note.tags,
      contentType: note.contentType,
      checklistItems: note.checklistItems,
    );
  }

  final String noteId;
  final String text;
  final String title;
  final String? folderId;
  final List<String> tags;
  final NoteContentType contentType;
  final List<NoteChecklistItem> checklistItems;
}
