import 'dart:async';

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
  Future<void> saveConversation(AiConversation conversation) async {
    _conversations[conversation.id] = conversation;
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
