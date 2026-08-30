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
    final document = await _collection().doc(conversationId).get();
    if (!document.exists) return null;
    return AiConversationDocumentMapper.fromDocument(document);
  }

  @override
  Stream<AiConversation?> watchConversation(String conversationId) {
    return _authService.userStream.switchMap((user) {
      if (user == null) return Stream.value(null);
      return _collectionFor(user.uid)
          .doc(conversationId)
          .snapshots()
          .map((document) {
            if (!document.exists) return null;
            return AiConversationDocumentMapper.fromDocument(document);
          });
    });
  }

  @override
  Future<void> saveConversation(AiConversation conversation) async {
    final reference = _collection().doc(conversation.id);
    await reference.set(
      AiConversationDocumentMapper.toMap(conversation),
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> saveMessage(String conversationId, AiChatMessage message) async {
    final reference = _collection().doc(conversationId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw StateError('AI conversation not found: $conversationId');
      }
      final conversation = AiConversationDocumentMapper.fromDocument(snapshot);
      final messages = [...conversation.messages];
      final index = messages.indexWhere(
        (candidate) => candidate.id == message.id,
      );
      if (index == -1) {
        messages.add(message);
      } else {
        messages[index] = message;
      }
      final updated = conversation.copyWith(
        updatedAt:
            message.createdAt.isAfter(conversation.updatedAt)
                ? message.createdAt
                : conversation.updatedAt,
        messages: messages,
      );
      transaction.set(
        reference,
        AiConversationDocumentMapper.toMap(updated),
        SetOptions(merge: true),
      );
    });
  }

  @override
  Future<void> deleteMessage(String conversationId, String messageId) async {
    final reference = _collection().doc(conversationId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) return;
      final conversation = AiConversationDocumentMapper.fromDocument(snapshot);
      final messages =
          conversation.messages
              .where((message) => message.id != messageId)
              .toList();
      final updated = conversation.copyWith(messages: messages);
      transaction.set(
        reference,
        AiConversationDocumentMapper.toMap(updated),
        SetOptions(merge: true),
      );
    });
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    await _collection().doc(conversationId).delete();
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
