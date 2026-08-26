import 'package:nexecute/repositories/firestore/schema/app_data_schema.dart';

typedef FirestoreDocumentMigration =
    void Function(Map<String, dynamic> document);

void noOpFirestoreDocumentMigration(Map<String, dynamic> _) {}

class FirestoreDocumentSchema {
  FirestoreDocumentSchema({
    required Map<int, FirestoreDocumentMigration> migrations,
  }) : _migrations = Map.unmodifiable(migrations);

  final Map<int, FirestoreDocumentMigration> _migrations;

  Map<String, dynamic> migrate(Map<String, dynamic> source) {
    final document = Map<String, dynamic>.from(source);
    var version = _readVersion(document);

    if (version > AppDataSchema.currentVersion) {
      throw UnsupportedError(
        'Document schema version $version is newer than supported version '
        '${AppDataSchema.currentVersion}',
      );
    }

    while (version < AppDataSchema.currentVersion) {
      final migration = _migrations[version];
      if (migration == null) {
        throw StateError(
          'Missing document migration from schema version $version',
        );
      }

      migration(document);
      version += 1;
      document[AppDataSchema.versionField] = version;
    }

    return document;
  }

  Map<String, dynamic> stamp(Map<String, dynamic> document) =>
      AppDataSchema.stamp(document);

  int _readVersion(Map<String, dynamic> document) {
    final value = document[AppDataSchema.versionField];
    if (value == null) return 0;
    if (value is int && value >= 0) return value;
    throw FormatException(
      '${AppDataSchema.versionField} must be a non-negative integer',
    );
  }
}
