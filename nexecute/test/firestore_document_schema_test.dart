import 'package:nexecute/repositories/firestore/schema/app_data_schema.dart';
import 'package:nexecute/repositories/firestore/schema/firestore_document_schema.dart';
import 'package:test/test.dart';

void main() {
  test('migrates an unversioned document and stamps the current version', () {
    final source = <String, dynamic>{'legacyTitle': 'Planning'};
    final schema = FirestoreDocumentSchema(
      migrations: {
        0: (document) {
          document['title'] = document.remove('legacyTitle');
        },
        1: noOpFirestoreDocumentMigration,
        2: noOpFirestoreDocumentMigration,
      },
    );

    final migrated = schema.migrate(source);

    expect(migrated, {
      'title': 'Planning',
      AppDataSchema.versionField: AppDataSchema.currentVersion,
    });
    expect(source, {'legacyTitle': 'Planning'});
  });

  test('rejects documents written by a newer application schema', () {
    final schema = FirestoreDocumentSchema(migrations: {0: (_) {}});

    expect(
      () => schema.migrate({
        AppDataSchema.versionField: AppDataSchema.currentVersion + 1,
      }),
      throwsUnsupportedError,
    );
  });

  test('rejects malformed schema versions', () {
    final schema = FirestoreDocumentSchema(migrations: {0: (_) {}});

    expect(
      () => schema.migrate({AppDataSchema.versionField: '1'}),
      throwsFormatException,
    );
  });

  test('fails when a required migration step has not been registered', () {
    final schema = FirestoreDocumentSchema(migrations: const {});

    expect(() => schema.migrate(const {}), throwsStateError);
  });
}
