import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:nexecute/services/auth.dart';
import 'package:nexecute/services/models.dart';
import 'package:uuid/uuid.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  var uuid = const Uuid();

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

  /// Listens to changes in quicxecslist in Firestore
  Stream<QuicxecsList> streamQuicxecsList() {
    return AuthService().userStream.switchMap((user) {
      if (user != null) {
        var ref = _db
            .collection('users')
            .doc(user.uid)
            .collection('quicxecs')
            .snapshots();
        //var asdf = ref.map<Quicxec>((doc) => Quicxec.fromJson(doc));
        return Stream.fromIterable([QuicxecsList()]);
      } else {
        return Stream.fromIterable([QuicxecsList()]);
      }
    });
  }

  /// Read Quicxecs from FireStore
  Future<QuicxecsList> getQuicxecs() async {
    var user = AuthService().user!;
    var ref = _db.collection('users').doc(user.uid);
    var snapshot = await ref.get();
    var data = snapshot.get(FieldPath(const ['quicxecs']));
    var quicxecs = data.map<Quicxec>((q) => Quicxec.fromJson(q));

    //print(quicxecs);

    return QuicxecsList(quicxecsList: quicxecs.toList());
  }

  Future<void> addNewQuicxec(text) async {
    var user = AuthService().user!;
    var ref = _db.collection('users').doc(user.uid).collection('quicxecs');
    var id = uuid.v1();
    var data = {
      'id': id,
      'text': text,
    };

    return ref.doc(id).set(data);
  }

  /// Modify currently open quicxec
  Future<void> modifyCurrentlyOpenQuicxec(quicxec, text) async {
    var user = AuthService().user!;
    var ref = _db.collection('users').doc(user.uid).collection('quicxecs');

    return ref.doc(quicxec.id).update({'text': text});
  }

  /// Removes currently open quicxec
  Future<void> removeCurrentlyOpenQuicxec(quicxec) async {
    var user = AuthService().user!;
    var ref = _db.collection('users').doc(user.uid).collection('quicxecs');

    return ref.doc(quicxec.id).delete();
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
