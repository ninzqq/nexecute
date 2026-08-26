import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/repositories/firestore/schema/firestore_document_schema.dart';

abstract final class NoteDocumentMapper {
  static final _schema = FirestoreDocumentSchema(
    migrations: {0: _migrateV0ToV1, 1: noOpFirestoreDocumentMigration},
  );

  static Map<String, dynamic> toMap(Quicxec note) => _schema.stamp({
    'id': note.id,
    'text': note.text,
    'title': note.title,
    'trashed': note.trashed,
    'tags': note.tags,
    'created': note.created,
    'contentType': note.contentType.name,
    'checklistItems': checklistItemsToData(note.checklistItems),
  });

  static Quicxec fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    return fromMap(document.id, document.data() ?? const {});
  }

  static Quicxec fromMap(String id, Map<String, dynamic> data) {
    final migrated = _schema.migrate(data);
    final rawItems = migrated['checklistItems'];
    return Quicxec(
      id: id,
      text: migrated['text']?.toString() ?? '',
      title: migrated['title']?.toString() ?? '',
      trashed: migrated['trashed'] == true,
      tags: _stringList(migrated['tags']),
      created: _date(migrated['created']) ?? DateTime.now(),
      contentType: NoteContentType.values.firstWhere(
        (type) => type.name == migrated['contentType'],
        orElse: () => NoteContentType.text,
      ),
      checklistItems:
          rawItems is List
              ? rawItems
                  .whereType<Map>()
                  .map(
                    (item) =>
                        _checklistItemFromMap(Map<String, dynamic>.from(item)),
                  )
                  .toList()
              : const [],
    );
  }

  static void _migrateV0ToV1(Map<String, dynamic> document) {
    document.putIfAbsent('title', () => '');
    document.putIfAbsent('trashed', () => false);
    document.putIfAbsent('tags', () => <String>[]);
    document.putIfAbsent('contentType', () => NoteContentType.text.name);
    document.putIfAbsent('checklistItems', () => <Map<String, dynamic>>[]);
  }

  static List<Map<String, dynamic>> checklistItemsToData(
    Iterable<NoteChecklistItem> items,
  ) {
    return items.map(_checklistItemToMap).toList();
  }

  static Map<String, dynamic> _checklistItemToMap(NoteChecklistItem item) => {
    'id': item.id,
    'text': item.text,
    'isChecked': item.isChecked,
  };

  static NoteChecklistItem _checklistItemFromMap(Map<String, dynamic> data) {
    return NoteChecklistItem(
      id: data['id']?.toString() ?? '',
      text: data['text']?.toString() ?? '',
      isChecked: data['isChecked'] == true,
    );
  }

  static DateTime? _date(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime date => date,
    _ => null,
  };

  static List<String> _stringList(Object? value) =>
      value is List ? value.map((item) => item.toString()).toList() : const [];
}
