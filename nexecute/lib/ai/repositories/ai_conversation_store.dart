import 'package:nexecute/ai/domain/ai_conversation.dart';

abstract interface class AiConversationStore {
  Stream<List<AiConversation>> watchConversations();

  Future<List<AiConversation>> getConversations();

  Future<AiConversation?> getConversation(String conversationId);

  Future<void> saveConversation(AiConversation conversation);

  Future<void> deleteConversation(String conversationId);

  void dispose();
}
