import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:nexecute/services/auth.dart';
import 'package:nexecute/services/models.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Listens to current user's button pushed count document in Firestore
  Stream<Count> streamCount() {
    return AuthService().userStream.switchMap((user) {
      if (user != null) {
        var ref = _db.collection('users').doc(user.uid);
        return ref.snapshots().map((doc) => Count.fromJson(doc.data()!));
      } else {
        return Stream.fromIterable([Count()]);
      }
    });
  }

  Stream<QuicxecsList> streamQuicxecList() {
    return AuthService().userStream.switchMap((user) {
      if (user != null) {
        var ref = _db.collection('quicxecs').doc(user.uid);
        return ref.snapshots().map((doc) => QuicxecsList.fromJson(doc.data()!));
      } else {
        return Stream.fromIterable([QuicxecsList()]);
      }
    });
  }

  /// Adds a new quicxec (quick task) for current user
  Future<void> addNewQuicxec(quicxec) {
    var user = AuthService().user!;
    var ref = _db.collection('quicxecs').doc(user.uid);

    var data = {
      "$quicxec": false,
    };

    return ref.set(data, SetOptions(merge: true));

    //return ref
    //    .update(data)
    //    .then((value) => print('[LOG] Quicxec added: $data'));
  }

  /// Updates the current user's count document after pressing button
  Future<void> updateUserPressCount() {
    var user = AuthService().user!;
    var ref = _db.collection('users').doc(user.uid);

    var data = {
      'count': FieldValue.increment(1),
    };

    return ref.set(data, SetOptions(merge: true));
  }
}
