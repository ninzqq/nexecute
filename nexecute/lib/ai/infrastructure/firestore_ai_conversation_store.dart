import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/ai/domain/ai_chat_message.dart';
import 'package:nexecute/ai/domain/ai_conversation.dart';
import 'package:nexecute/ai/infrastructure/ai_conversation_document_mapper.dart';
import 'package:nexecute/ai/repositories/ai_conversation_store.dart';
import 'package:nexecute/services/auth.dart';
import 'package:rxdart/rxdart.dart';

class FirestoreAiConversationStore implements AiConversationStore {
  FirestoreAiConversationStore({
    required AuthService authService,
    FirebaseFirestore? firestore,
  }) : _authService = authService,
       _db = firestore ?? FirebaseFirestore.instance;

  final AuthService _authService;
  final FirebaseFirestore _db;

  @override
  Stream<List<AiConversation>> watchConversations() {
    return _authService.userStream.switchMap((user) {
      if (user == null) return Stream.value(const <AiConversation>[]);
      return _collectionFor(user.uid)
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => List.unmodifiable(
              snapshot.docs.map(AiConversationDocumentMapper.fromDocument),
            ),
          );
    });
  }

  @override
  Future<List<AiConversation>> getConversations() async {
    final snapshot =
        await _collection().orderBy('updatedAt', descending: true).get();
    return List.unmodifiable(
      snapshot.docs.map(AiConversationDocumentMapper.fromDocument),
    );
  }

  @override
  Future<AiConversation?> getConversation(String conversationId) async {
    final reference = _collection().doc(conversationId);
    final results = await Future.wait([
      reference.get(),
      reference.collection('messages').orderBy('createdAt').get(),
    ]);
    final document = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    if (!document.exists) return null;
    final messages = results[1] as QuerySnapshot<Map<String, dynamic>>;
    return AiConversationDocumentMapper.fromDocument(
      document,
      messages:
          messages.docs
              .map(AiConversationDocumentMapper.messageFromDocument)
              .toList(),
    );
  }

  @override
  Stream<AiConversation?> watchConversation(String conversationId) {
    return _authService.userStream.switchMap((user) {
      if (user == null) return Stream.value(null);
      final reference = _collectionFor(user.uid).doc(conversationId);
      return Rx.combineLatest2(
        reference.snapshots(),
        reference.collection('messages').orderBy('createdAt').snapshots(),
        (
          DocumentSnapshot<Map<String, dynamic>> document,
          QuerySnapshot<Map<String, dynamic>> messages,
        ) {
          if (!document.exists) return null;
          return AiConversationDocumentMapper.fromDocument(
            document,
            messages:
                messages.docs
                    .map(AiConversationDocumentMapper.messageFromDocument)
                    .toList(),
          );
        },
      );
    });
  }

  @override
  Future<void> saveConversation(AiConversation conversation) async {
    final reference = _collection().doc(conversation.id);
    await reference.set(
      AiConversationDocumentMapper.conversationMetadataToMap(conversation),
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> saveMessage(String conversationId, AiChatMessage message) async {
    final reference = _collection().doc(conversationId);
    final batch = _db.batch();
    batch.set(
      reference.collection('messages').doc(message.id),
      AiConversationDocumentMapper.messageToMap(message),
    );
    batch.update(reference, {'updatedAt': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  @override
  Future<void> deleteMessage(String conversationId, String messageId) async {
    final reference = _collection().doc(conversationId);
    final batch = _db.batch();
    batch.delete(reference.collection('messages').doc(messageId));
    batch.update(reference, {'updatedAt': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    final reference = _collection().doc(conversationId);
    while (true) {
      final snapshot = await reference.collection('messages').limit(400).get();
      if (snapshot.docs.isEmpty) break;
      final batch = _db.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
    await reference.delete();
  }

  CollectionReference<Map<String, dynamic>> _collection() {
    final user = _authService.user;
    if (user == null) throw StateError('User is not logged in');
    return _collectionFor(user.uid);
  }

  CollectionReference<Map<String, dynamic>> _collectionFor(String userId) =>
      _db.collection('users').doc(userId).collection('aiConversations');

  @override
  void dispose() {}
}
