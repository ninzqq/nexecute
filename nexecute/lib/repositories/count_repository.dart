import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/models/count.dart';
import 'package:nexecute/services/auth.dart';
import 'package:rxdart/rxdart.dart';

abstract interface class CountRepository {
  Stream<Count> watchCount();

  Future<void> increment();
}

class FirestoreCountRepository implements CountRepository {
  FirestoreCountRepository({
    required AuthService authService,
    FirebaseFirestore? firestore,
  }) : _authService = authService,
       _db = firestore ?? FirebaseFirestore.instance;

  final AuthService _authService;
  final FirebaseFirestore _db;

  @override
  Stream<Count> watchCount() {
    return _authService.userStream.switchMap((user) {
      if (user == null) return Stream.value(Count());

      return _db
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((document) => Count.fromJson(document.data() ?? const {}));
    });
  }

  @override
  Future<void> increment() {
    final user = _authService.user;
    if (user == null) throw StateError('User is not logged in');
    return _db.collection('users').doc(user.uid).set({
      'count': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }
}
