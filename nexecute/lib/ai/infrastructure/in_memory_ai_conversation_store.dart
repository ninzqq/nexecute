import 'dart:async';

import 'package:nexecute/ai/domain/ai_chat_message.dart';
import 'package:nexecute/ai/domain/ai_conversation.dart';
import 'package:nexecute/ai/repositories/ai_conversation_store.dart';

class InMemoryAiConversationStore implements AiConversationStore {
  InMemoryAiConversationStore({
    Iterable<AiConversation> conversations = const [],
  }) : _conversations = {
         for (final conversation in conversations)
           conversation.id: conversation,
       };

  final Map<String, AiConversation> _conversations;
  final _controller = StreamController<List<AiConversation>>.broadcast();

  @override
  Stream<List<AiConversation>> watchConversations() async* {
    yield await getConversations();
    yield* _controller.stream;
  }

  @override
  Future<List<AiConversation>> getConversations() async {
    final conversations =
        _conversations.values.toList()..sort(
          (first, second) => second.updatedAt.compareTo(first.updatedAt),
        );
    return List.unmodifiable(conversations);
  }

  @override
  Future<AiConversation?> getConversation(String conversationId) async =>
      _conversations[conversationId];

  @override
  Stream<AiConversation?> watchConversation(String conversationId) async* {
    yield _conversations[conversationId];
    yield* _controller.stream.map((_) => _conversations[conversationId]);
  }

  @override
  Future<void> saveConversation(AiConversation conversation) async {
    _conversations[conversation.id] = conversation;
    _controller.add(await getConversations());
  }

  @override
  Future<void> saveMessage(String conversationId, AiChatMessage message) async {
    final conversation = _conversations[conversationId];
    if (conversation == null) {
      throw StateError('AI conversation not found: $conversationId');
    }
    final messages = [...conversation.messages];
    final index = messages.indexWhere(
      (candidate) => candidate.id == message.id,
    );
    if (index == -1) {
      messages.add(message);
    } else {
      messages[index] = message;
    }
    _conversations[conversationId] = conversation.copyWith(
      updatedAt:
          message.createdAt.isAfter(conversation.updatedAt)
              ? message.createdAt
              : conversation.updatedAt,
      messages: messages,
    );
    _controller.add(await getConversations());
  }

  @override
  Future<void> deleteMessage(String conversationId, String messageId) async {
    final conversation = _conversations[conversationId];
    if (conversation == null) return;
    _conversations[conversationId] = conversation.copyWith(
      messages:
          conversation.messages
              .where((message) => message.id != messageId)
              .toList(),
    );
    _controller.add(await getConversations());
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    if (_conversations.remove(conversationId) == null) return;
    _controller.add(await getConversations());
  }

  @override
  void dispose() {
    _controller.close();
  }
}
