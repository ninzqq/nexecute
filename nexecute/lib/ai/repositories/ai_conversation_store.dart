import 'package:nexecute/ai/domain/ai_conversation.dart';
import 'package:nexecute/ai/domain/ai_chat_message.dart';

abstract interface class AiConversationStore {
  Stream<List<AiConversation>> watchConversations();

  Future<List<AiConversation>> getConversations();

  Future<AiConversation?> getConversation(String conversationId);

  Stream<AiConversation?> watchConversation(String conversationId);

  Future<void> saveConversation(AiConversation conversation);

  Future<void> saveMessage(String conversationId, AiChatMessage message);

  Future<void> deleteMessage(String conversationId, String messageId);

  Future<void> deleteConversation(String conversationId);

  void dispose();
}
