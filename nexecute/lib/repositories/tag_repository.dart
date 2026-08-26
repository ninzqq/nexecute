import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/tag.dart';
import 'package:nexecute/repositories/firestore/tag_document_mapper.dart';
import 'package:nexecute/repositories/firestore/schema/app_data_schema.dart';
import 'package:nexecute/services/auth.dart';
import 'package:nexecute/services/authenticated_data_stream.dart';

abstract interface class TagRepository {
  Stream<DataState<Tags>> watchTags();

  Future<void> addTag(String tag);

  Future<void> removeTag(String tag);
}

class FirestoreTagRepository implements TagRepository {
  FirestoreTagRepository({
    required AuthService authService,
    FirebaseFirestore? firestore,
  }) : _authService = authService,
       _db = firestore ?? FirebaseFirestore.instance;

  final AuthService _authService;
  final FirebaseFirestore _db;

  @override
  Stream<DataState<Tags>> watchTags() {
    return authenticatedDataStream(
      authentication: _authService.userStream,
      isEmpty: (tags) => tags.tags.isEmpty,
      load:
          (user) => _db
              .collection('users')
              .doc(user.uid)
              .snapshots()
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
