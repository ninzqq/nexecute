import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:nexecute/services/auth.dart';
import 'package:nexecute/services/models.dart';
import 'package:uuid/uuid.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  var uuid = const Uuid();

  /// Listens to changes in quicxecslist in Firestore
  Stream<List<Quicxec>> streamQuicxecs() {
    return AuthService().userStream.switchMap((user) {
      if (user != null) {
        var ref = _db
            .collection('users')
            .doc(user.uid)
            .collection('quicxecs')
            .snapshots();

        return ref.map((list) =>
            list.docs.map((doc) => Quicxec.fromJson(doc.data())).toList());
      } else {
        return Stream.fromIterable([]);
      }
    });
  }

  Future<void> addNewQuicxec(text, title, tags) async {
    var user = AuthService().user!;
    var ref = _db.collection('users').doc(user.uid).collection('quicxecs');
    var id = uuid.v1();
    var data = {
      'id': id,
      'text': text,
      'title': title,
      'trashed': false,
      'tags': tags,
    };

    return ref.doc(id).set(data);
  }

  /// Modify currently open quicxec
  Future<void> modifyCurrentlyOpenQuicxec(
      quicxec, newText, newTitle, tags) async {
    var user = AuthService().user!;
    var ref = _db.collection('users').doc(user.uid).collection('quicxecs');

    return ref.doc(quicxec.id).update({
      'text': newText,
      'title': newTitle,
      'tags': tags,
    });
  }

  /// Removes currently open quicxec
  Future<void> moveCurrentlyOpenQuicxec(Quicxec quicxec) async {
    var user = AuthService().user!;
    var ref = _db.collection('users').doc(user.uid).collection('quicxecs');

    return ref.doc(quicxec.id).update({'trashed': !quicxec.trashed});
  }

  /// Empty trash permanently
  Future<void> emptyTrash() async {
    var user = AuthService().user!;
    var batch = _db.batch();
    var collection = _db
        .collection('users')
        .doc(user.uid)
        .collection('quicxecs')
        .where('trashed', isEqualTo: true);
    var snapshot = await collection.get();

    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    return;
  }

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
