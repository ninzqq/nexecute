import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/models/note_folder.dart';
import 'package:nexecute/repositories/firestore/schema/firestore_document_schema.dart';

abstract final class NoteFolderDocumentMapper {
  static final _schema = FirestoreDocumentSchema(
    migrations: {
      0: noOpFirestoreDocumentMigration,
      1: noOpFirestoreDocumentMigration,
      2: _migrateV2ToV3,
    },
  );

  static Map<String, dynamic> toMap(NoteFolder folder) => _schema.stamp({
    'name': folder.name,
    'createdAt': folder.createdAt,
    'updatedAt': folder.updatedAt,
  });

  static NoteFolder fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) => fromMap(document.id, document.data() ?? const {});

  static NoteFolder fromMap(String id, Map<String, dynamic> data) {
    final migrated = _schema.migrate(data);
    final createdAt = _date(migrated['createdAt']) ?? DateTime.now();
    return NoteFolder(
      id: id,
      name: migrated['name']?.toString() ?? '',
      createdAt: createdAt,
      updatedAt: _date(migrated['updatedAt']) ?? createdAt,
    );
  }

  static void _migrateV2ToV3(Map<String, dynamic> document) {
    document.putIfAbsent('name', () => 'Untitled folder');
    document.putIfAbsent('createdAt', DateTime.now);
    document.putIfAbsent('updatedAt', () => document['createdAt']);
  }

  static DateTime? _date(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime date => date,
    _ => null,
  };
}
