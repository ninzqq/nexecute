import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/models/event.dart';
import 'package:rxdart/rxdart.dart';
import 'package:nexecute/services/auth.dart';
import 'package:uuid/uuid.dart';
import 'package:nexecute/models/count.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/tag.dart';
import 'package:logger/logger.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  var uuid = const Uuid();
  var logger = Logger();

  /// Listens to changes in quicxecslist in Firestore
  Stream<List<Quicxec>> streamQuicxecs() {
    return AuthService().userStream.switchMap((user) {
      if (user != null) {
        var ref =
            _db
                .collection('users')
                .doc(user.uid)
                .collection('quicxecs')
                .snapshots();

        return ref.map((list) {
          logger.i("Firestore snapshot received");
          return list.docs.map((doc) {
            try {
              return Quicxec.fromFirestore(doc);
            } catch (e) {
              logger.e("Error converting doc to Quicxec: $e");
              rethrow;
            }
          }).toList();
        });
      } else {
        logger.e("No authenticated user, returning empty stream");
        return Stream.fromIterable([]);
      }
    });
  }

  /// Listens to changes in eventslist in Firestore
  Stream<List<Event>> streamEvents() {
    return AuthService().userStream.switchMap((user) {
      if (user != null) {
        var ref =
            _db
                .collection('users')
                .doc(user.uid)
                .collection('events')
                .snapshots();

        return ref.map((list) {
          logger.i("Firestore snapshot received");
          return list.docs.map((doc) {
            try {
              return Event.fromFirestore(doc);
            } catch (e) {
              logger.e("Error converting doc to Event: $e");
              rethrow;
            }
          }).toList();
        });
      } else {
        logger.e("No authenticated user, returning empty stream");
        return Stream.fromIterable([]);
      }
    });
  }

  Future<void> addNewQuicxec(Quicxec quicxec) async {
    var user = AuthService().user!;
    var ref = _db.collection('users').doc(user.uid).collection('quicxecs');
    var id = uuid.v1();
    var data = {
      'id': id,
      'text': quicxec.text,
      'title': quicxec.title,
      'trashed': false,
      'tags': quicxec.tags,
      'created': quicxec.created,
    };

    return ref.doc(id).set(data);
  }

  /// Modify currently open quicxec
  Future<void> modifyCurrentlyOpenQuicxec(
    quicxec,
    newText,
    newTitle,
    tags,
  ) async {
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

  /// Add new event
  Future<void> addNewEvent(Event event) async {
    var user = AuthService().user!;
    var ref = _db.collection('users').doc(user.uid).collection('events');
    var id = uuid.v1();
    var data = {
      'id': id,
      'title': event.title,
      'description': event.description,
      'startTime': event.startTime,
      'endTime': event.endTime,
      'isAllDay': event.isAllDay,
    };

    return ref.doc(id).set(data);
  }

  /// Modify currently open event
  Future<void> modifyCurrentlyOpenEvent(
    event,
    newTitle,
    newDescription,
    newStartTime,
    newEndTime,
    newIsAllDay,
  ) async {
    var user = AuthService().user!;
    var ref = _db.collection('users').doc(user.uid).collection('events');

    return ref.doc(event.id).update({
      'title': newTitle,
      'description': newDescription,
      'startTime': newStartTime,
      'endTime': newEndTime,
      'isAllDay': newIsAllDay,
    });
  }

  /// Delete currently open event
  Future<void> deleteCurrentlyOpenEvent(Event event) async {
    try {
      // Check that user is logged in
      final user = AuthService().user;
      if (user == null) {
        throw Exception('User is not logged in');
      }

      // Check that event has ID
      if (event.id.isEmpty) {
        throw Exception('Event has no ID');
      }

      // Haetaan eventin viite
      final ref = _db.collection('users').doc(user.uid).collection('events');

      // Check that event exists before deletion
      final docSnapshot = await ref.doc(event.id).get();
      if (!docSnapshot.exists) {
        throw Exception('Event not found');
      }

      // Perform deletion
      await ref.doc(event.id).delete();
    } on FirebaseException catch (e) {
      // Firebase errors
      throw Exception('Error deleting event: ${e.message}');
    } catch (e) {
      // Other errors
      throw Exception('Unexpected error: $e');
    }
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

  /// Permanently delete a single quicxec
  Future<void> permanentlyDeleteSingleQuicxec(Quicxec quicxec) async {
    var user = AuthService().user!;
    var ref = _db.collection('users').doc(user.uid).collection('quicxecs');

    return ref.doc(quicxec.id).delete();
  }

  /// Convert quicxec to event
  Future<void> convertQuicxecToEvent(Quicxec quicxec) async {
    try {
      var user = AuthService().user;
      if (user == null) {
        throw Exception('User is not logged in');
      }

      Event newEvent = Event(
        id: quicxec.id,
        title: quicxec.title,
        description: quicxec.text,
        startTime: quicxec.created,
        endTime: quicxec.created,
      );

      await addNewEvent(newEvent);
      await permanentlyDeleteSingleQuicxec(quicxec);
    } on FirebaseException catch (e) {
      throw Exception('Error converting quicxec to event: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Convert event to quicxec
  Future<void> convertEventToQuicxec(Event event) async {
    try {
      var user = AuthService().user;
      if (user == null) {
        throw Exception('User is not logged in');
      }

      Quicxec newQuicxec = Quicxec(
        id: event.id,
        title: event.title,
        text: event.description,
        created: event.startTime,
      );

      await addNewQuicxec(newQuicxec);
      await deleteCurrentlyOpenEvent(event);
    } on FirebaseException catch (e) {
      throw Exception('Error converting event to quicxec: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  /// Stream tags
  Stream<Tags> streamTags() {
    return AuthService().userStream.switchMap((user) {
      if (user != null) {
        var ref = _db.collection('users').doc(user.uid).snapshots();
        return ref.map((doc) => Tags.fromJson(doc.data()!));
      } else {
        return Stream.fromIterable([]);
      }
    });
  }

  /// Add new tag
  Future<void> addNewTag(tag) async {
    var user = AuthService().user!;
    var ref = _db.collection('users').doc(user.uid);

    return ref.update({
      'tags': FieldValue.arrayUnion([tag]),
    });
  }

  /// Remove selected tag
  Future<void> removeSelectedTag(tag) async {
    var user = AuthService().user!;
    var ref = _db.collection('users').doc(user.uid);

    return ref.update({
      'tags': FieldValue.arrayRemove([tag]),
    });
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

    var data = {'count': FieldValue.increment(1)};

    return ref.set(data, SetOptions(merge: true));
  }
}
