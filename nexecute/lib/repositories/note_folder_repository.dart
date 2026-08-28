import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/note_folder.dart';
import 'package:nexecute/repositories/firestore/note_folder_document_mapper.dart';
import 'package:nexecute/repositories/firestore/schema/app_data_schema.dart';
import 'package:nexecute/services/auth.dart';
import 'package:nexecute/services/authenticated_data_stream.dart';
import 'package:uuid/uuid.dart';

abstract interface class NoteFolderRepository {
  Stream<DataState<List<NoteFolder>>> watchFolders();

  Future<void> addFolder(String name);

  Future<void> renameFolder(String folderId, String name);

  Future<void> deleteFolder(String folderId);
}

class FirestoreNoteFolderRepository implements NoteFolderRepository {
  FirestoreNoteFolderRepository({
    required AuthService authService,
    FirebaseFirestore? firestore,
    Uuid uuid = const Uuid(),
  }) : _authService = authService,
       _db = firestore ?? FirebaseFirestore.instance,
       _uuid = uuid;

  static const _batchSize = 450;

  final AuthService _authService;
  final FirebaseFirestore _db;
  final Uuid _uuid;

  @override
  Stream<DataState<List<NoteFolder>>> watchFolders() {
    return authenticatedDataStream(
      authentication: _authService.userStream,
      isEmpty: (folders) => folders.isEmpty,
      load:
          (user) => _db
              .collection('users')
              .doc(user.uid)
              .collection('noteFolders')
              .snapshots()
              .map((snapshot) {
                final folders =
                    snapshot.docs
                        .map(NoteFolderDocumentMapper.fromDocument)
                        .toList();
                folders.sort(
                  (first, second) => first.name.toLowerCase().compareTo(
                    second.name.toLowerCase(),
                  ),
                );
                return folders;
              }),
    );
  }

  @override
  Future<void> addFolder(String name) async {
    final normalizedName = _validName(name);
    final now = DateTime.now();
    final id = _uuid.v1();
    await _foldersCollection()
        .doc(id)
        .set(
          NoteFolderDocumentMapper.toMap(
            NoteFolder(
              id: id,
              name: normalizedName,
              createdAt: now,
              updatedAt: now,
            ),
          ),
        );
  }

  @override
  Future<void> renameFolder(String folderId, String name) {
    if (folderId.isEmpty) throw StateError('Folder has no ID');
    return _foldersCollection()
        .doc(folderId)
        .update(
          AppDataSchema.stamp({
            'name': _validName(name),
            'updatedAt': DateTime.now(),
          }),
        );
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    if (folderId.isEmpty) throw StateError('Folder has no ID');

    final notes =
        await _notesCollection().where('folderId', isEqualTo: folderId).get();
    final documents = notes.docs;
    final now = DateTime.now();

    for (var start = 0; start < documents.length; start += _batchSize) {
      final end = (start + _batchSize).clamp(0, documents.length);
      final batch = _db.batch();
      for (final document in documents.sublist(start, end)) {
        batch.update(
          document.reference,
          AppDataSchema.stamp({'folderId': null, 'updatedAt': now}),
        );
      }
      await batch.commit();
    }

    await _foldersCollection().doc(folderId).delete();
  }

  String _validName(String name) {
    final value = name.trim();
    if (value.isEmpty) throw ArgumentError.value(name, 'name', 'is empty');
    return value;
  }

  CollectionReference<Map<String, dynamic>> _foldersCollection() {
    final user = _authService.user;
    if (user == null) throw StateError('User is not logged in');
    return _db.collection('users').doc(user.uid).collection('noteFolders');
  }

  CollectionReference<Map<String, dynamic>> _notesCollection() {
    final user = _authService.user;
    if (user == null) throw StateError('User is not logged in');
    return _db.collection('users').doc(user.uid).collection('quicxecs');
  }
}
