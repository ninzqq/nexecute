import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/models/tag.dart';
import 'package:nexecute/services/auth.dart';
import 'package:rxdart/rxdart.dart';

abstract interface class TagRepository {
  Stream<Tags> watchTags();

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
  Stream<Tags> watchTags() {
    return _authService.userStream.switchMap((user) {
      if (user == null) return Stream.value(Tags());

      return _db
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((document) => Tags.fromJson(document.data() ?? const {}));
    });
  }

  @override
  Future<void> addTag(String tag) {
    return _userDocument().update({
      'tags': FieldValue.arrayUnion([tag]),
    });
  }

  @override
  Future<void> removeTag(String tag) {
    return _userDocument().update({
      'tags': FieldValue.arrayRemove([tag]),
    });
  }

  DocumentReference<Map<String, dynamic>> _userDocument() {
    final user = _authService.user;
    if (user == null) throw StateError('User is not logged in');
    return _db.collection('users').doc(user.uid);
  }
}
