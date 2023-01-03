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

        return QuicxecsList(
            quicxecsList: ref.map((list) =>
                    list.docs.map((doc) => Quicxec.fromJson(doc.data())))
                as List<Quicxec>) as Stream<QuicxecsList>;
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
  Future<void> moveCurrentlyOpenQuicxecToTrash(quicxec) async {
    var user = AuthService().user!;
    var refOriginal =
        _db.collection('users').doc(user.uid).collection('quicxecs');
    var refTrash = _db.collection('users').doc(user.uid).collection('trash');

    // Copy to trash
    var data = {
      'id': quicxec.id,
      'text': quicxec.text,
    };
    refTrash.doc(quicxec.id).set(data);

    return refOriginal.doc(quicxec.id).delete();
  }

  /// Empty trash permanently
  Future<void> emptyTrash() async {
    var user = AuthService().user!;
    var batch = _db.batch();
    var collection = _db.collection('users').doc(user.uid).collection('trash');
    var snapshots = await collection.get();

    for (var doc in snapshots.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    return;
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
