import 'package:nexecute/models/note_folder.dart';
import 'package:nexecute/repositories/firestore/note_folder_document_mapper.dart';
import 'package:nexecute/repositories/firestore/schema/app_data_schema.dart';
import 'package:test/test.dart';

void main() {
  test('round-trips a note folder at the current schema version', () {
    final createdAt = DateTime(2026, 8, 28, 9);
    final updatedAt = DateTime(2026, 8, 28, 10);
    final folder = NoteFolder(
      id: 'folder-1',
      name: 'Projects',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final data = NoteFolderDocumentMapper.toMap(folder);
    final restored = NoteFolderDocumentMapper.fromMap(folder.id, data);

    expect(data[AppDataSchema.versionField], AppDataSchema.currentVersion);
    expect(restored.id, folder.id);
    expect(restored.name, 'Projects');
    expect(restored.createdAt, createdAt);
    expect(restored.updatedAt, updatedAt);
  });

  test('migrates an unversioned folder safely', () {
    final folder = NoteFolderDocumentMapper.fromMap('legacy-folder', const {});

    expect(folder.name, 'Untitled folder');
    expect(folder.updatedAt, folder.createdAt);
  });
}
