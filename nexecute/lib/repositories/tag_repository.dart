import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/tag.dart';
import 'package:nexecute/repositories/firestore/tag_document_mapper.dart';
import 'package:nexecute/repositories/firestore/schema/app_data_schema.dart';
import 'package:nexecute/services/auth.dart';
import 'package:nexecute/services/authenticated_data_stream.dart';
import 'package:nexecute/services/firestore_read_diagnostics.dart';

abstract interface class TagRepository {
  Stream<DataState<Tags>> watchTags();

  Future<void> addTag(String tag);

  Future<void> removeTag(String tag);
}

class FirestoreTagRepository implements TagRepository {
  FirestoreTagRepository({
    required AuthService authService,
    FirebaseFirestore? firestore,
    FirestoreReadDiagnostics? readDiagnostics,
  }) : _authService = authService,
       _db = firestore ?? FirebaseFirestore.instance,
       _readDiagnostics = readDiagnostics ?? FirestoreReadDiagnostics.disabled;

  final AuthService _authService;
  final FirebaseFirestore _db;
  final FirestoreReadDiagnostics _readDiagnostics;

  @override
  Stream<DataState<Tags>> watchTags() {
    return authenticatedDataStream(
      authentication: _authService.userStream,
      isEmpty: (tags) => tags.tags.isEmpty,
      load:
          (user) => _readDiagnostics
              .watchDocument(
                operation: 'tags.userDocument',
                document: _db.collection('users').doc(user.uid),
              )
              .map(
                (document) =>
                    TagDocumentMapper.fromMap(document.data() ?? const {}),
              ),
    );
  }

  @override
  Future<void> addTag(String tag) {
    return _userDocument().set(
      AppDataSchema.stamp({
        'tags': FieldValue.arrayUnion([tag]),
      }),
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> removeTag(String tag) {
    return _userDocument().set(
      AppDataSchema.stamp({
        'tags': FieldValue.arrayRemove([tag]),
      }),
      SetOptions(merge: true),
    );
  }

  DocumentReference<Map<String, dynamic>> _userDocument() {
    final user = _authService.user;
    if (user == null) throw StateError('User is not logged in');
    return _db.collection('users').doc(user.uid);
  }
}
