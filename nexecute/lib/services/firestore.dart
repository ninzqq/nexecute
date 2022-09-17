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

  Stream<List<Quicxec>> streamQuicxecList() {
    return AuthService().userStream.switchMap((user) {
      if (user != null) {
        Stream<DocumentSnapshot> ref =
            _db.collection('users').doc(user.uid).snapshots();
        var asdf = ref.map((doc) {
          return Quicxec.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();
        return asdf.asStream();
      } else {
        return Stream.fromIterable([]);
      }
    });
  }

  Future<List<Quicxec>> getQuicxecs() async {
    var user = AuthService().user!;
    var ref = _db.collection('users').doc(user.uid);
    var snapshot = await ref.get();
    var data = snapshot.get(FieldPath(const ['quicxecs']));
    var quicxecs = data.map<Quicxec>((q) => Quicxec.fromJson(q));

    return quicxecs.toList();
  }

  /// Adds a new quicxec (quick task) for current user
  Future<void> addNewQuicxec(quicxec) async {
    var user = AuthService().user!;
    var ref = _db.collection('users').doc(user.uid);
    var snapshot = await ref.get();
    var quicxecs = snapshot.get(FieldPath(const ['quicxecs']));

    print(ref.toString());

    var data = {
      'quicxecs[4][title]': '$quicxec',
      'quicxecs[4][done]': false,
    };

    return ref.set(data, SetOptions(merge: true));
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
