import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/repositories/firestore/note_document_mapper.dart';
import 'package:test/test.dart';

void main() {
  test('older notes without checklist fields remain text notes', () {
    final note = NoteDocumentMapper.fromMap('legacy-note', {
      'title': 'Legacy',
      'text': 'Plain text',
      'created': DateTime(2026, 8, 24),
      'tags': ['old'],
    });

    expect(note.contentType, NoteContentType.text);
    expect(note.checklistItems, isEmpty);
    expect(note.contentAsPlainText, 'Plain text');
  });

  test('checklist notes round-trip through Firestore-compatible data', () {
    final note = Quicxec(
      id: 'checklist-note',
      title: 'Shopping',
      text: 'Milk\nBread',
      created: DateTime(2026, 8, 24),
      contentType: NoteContentType.checklist,
      checklistItems: const [
        NoteChecklistItem(id: 'milk', text: 'Milk', isChecked: true),
        NoteChecklistItem(id: 'bread', text: 'Bread'),
      ],
    );

    final restored = NoteDocumentMapper.fromMap(
      note.id,
      NoteDocumentMapper.toMap(note),
    );

    expect(restored.contentType, NoteContentType.checklist);
    expect(restored.checklistItems, hasLength(2));
    expect(restored.checklistItems.first.text, 'Milk');
    expect(restored.checklistItems.first.isChecked, isTrue);
    expect(restored.contentAsPlainText, '☑ Milk\n☐ Bread');
    expect(restored.searchableText, contains('Bread'));
  });
}
