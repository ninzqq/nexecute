import 'package:nexecute/models/tag.dart';
import 'package:nexecute/repositories/firestore/schema/firestore_document_schema.dart';

abstract final class TagDocumentMapper {
  static final _schema = FirestoreDocumentSchema(
    migrations: {0: _migrateV0ToV1},
  );

  static Map<String, dynamic> toMap(Tags tags) =>
      _schema.stamp({'tags': tags.tags});

  static Tags fromMap(Map<String, dynamic> data) {
    final migrated = _schema.migrate(data);
    final values = migrated['tags'];
    return Tags(
      tags:
          values is List
              ? values.map((value) => value.toString()).toList()
              : const [],
    );
  }

  static void _migrateV0ToV1(Map<String, dynamic> document) {
    document.putIfAbsent('tags', () => <String>[]);
  }
}
