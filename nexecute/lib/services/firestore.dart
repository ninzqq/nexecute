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

  /// Adds a new quicxec (quick task) for current user
  Future<void> addNewQuicxec(quicxec) async {
    var user = AuthService().user!;
    var ref = _db.collection('users').doc(user.uid);

    var id = DateTime.now().millisecondsSinceEpoch.toInt();

    var data = [
      {
        'id': id,
        'title': quicxec,
        'done': false,
      }
    ];

    return ref.update({'quicxecs': FieldValue.arrayUnion(data)});
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
