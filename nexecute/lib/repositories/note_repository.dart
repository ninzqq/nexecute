import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/repositories/commands/update_note_command.dart';
import 'package:nexecute/repositories/firestore/note_document_mapper.dart';
import 'package:nexecute/repositories/firestore/schema/app_data_schema.dart';
import 'package:nexecute/services/auth.dart';
import 'package:nexecute/services/authenticated_data_stream.dart';
import 'package:uuid/uuid.dart';

export 'package:nexecute/repositories/commands/update_note_command.dart';

abstract interface class NoteRepository {
  Stream<DataState<List<Quicxec>>> watchNotes();

  Future<void> addNote(Quicxec note);

  Future<void> updateNote(UpdateNoteCommand command);

  Future<void> setChecklistItemChecked(
    Quicxec note,
    String itemId,
    bool isChecked,
  );

  Future<void> toggleTrashed(Quicxec note);

  Future<void> emptyTrash();

  Future<void> deletePermanently(Quicxec note);
}

class FirestoreNoteRepository implements NoteRepository {
  FirestoreNoteRepository({
    required AuthService authService,
    FirebaseFirestore? firestore,
    Uuid uuid = const Uuid(),
  }) : _authService = authService,
       _db = firestore ?? FirebaseFirestore.instance,
       _uuid = uuid;

  final AuthService _authService;
  final FirebaseFirestore _db;
  final Uuid _uuid;

  @override
  Stream<DataState<List<Quicxec>>> watchNotes() {
    return authenticatedDataStream(
      authentication: _authService.userStream,
      isEmpty: (notes) => notes.isEmpty,
      load:
          (user) => _db
              .collection('users')
              .doc(user.uid)
              .collection('quicxecs')
              .snapshots()
              .map(
                (snapshot) =>
                    snapshot.docs.map(NoteDocumentMapper.fromDocument).toList(),
              ),
    );
  }

  @override
  Future<void> addNote(Quicxec note) async {
    final id = _uuid.v1();
    final data = NoteDocumentMapper.toMap(note);
    data['id'] = id;
    data['trashed'] = false;
    await _notesCollection().doc(id).set(data);
  }

  @override
  Future<void> updateNote(UpdateNoteCommand command) async {
    if (command.noteId.isEmpty) throw StateError('Note has no ID');

    await _notesCollection()
        .doc(command.noteId)
        .update(
          AppDataSchema.stamp({
            'text': command.text,
            'title': command.title,
            'tags': command.tags,
            'contentType': command.contentType.name,
            'checklistItems': NoteDocumentMapper.checklistItemsToData(
              command.checklistItems,
            ),
          }),
        );
  }

  @override
  Future<void> setChecklistItemChecked(
    Quicxec note,
    String itemId,
    bool isChecked,
  ) async {
    final items =
        note.checklistItems
            .map(
              (item) =>
                  item.id == itemId
                      ? item.copyWith(isChecked: isChecked)
                      : item,
            )
            .toList();

    await _notesCollection()
        .doc(note.id)
        .update(
          AppDataSchema.stamp({
            'text': items.map((item) => item.text).join('\n'),
            'checklistItems': NoteDocumentMapper.checklistItemsToData(items),
          }),
        );
  }

  @override
  Future<void> toggleTrashed(Quicxec note) {
    return _notesCollection()
        .doc(note.id)
        .update(AppDataSchema.stamp({'trashed': !note.trashed}));
  }

  @override
  Future<void> emptyTrash() async {
    final batch = _db.batch();
    final snapshot =
        await _notesCollection().where('trashed', isEqualTo: true).get();

    for (final document in snapshot.docs) {
      batch.delete(document.reference);
    }
    await batch.commit();
  }

  @override
  Future<void> deletePermanently(Quicxec note) {
    return _notesCollection().doc(note.id).delete();
  }

  CollectionReference<Map<String, dynamic>> _notesCollection() {
    final user = _authService.user;
    if (user == null) throw StateError('User is not logged in');
    return _db.collection('users').doc(user.uid).collection('quicxecs');
  }
}
