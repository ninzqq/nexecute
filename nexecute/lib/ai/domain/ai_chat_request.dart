import 'package:nexecute/ai/domain/ai_chat_message.dart';
import 'package:nexecute/ai/domain/ai_connection_profile.dart';

class AiChatRequest {
  AiChatRequest({
    required this.connectionProfile,
    required this.conversationId,
    required List<AiChatMessage> messages,
    this.systemInstruction,
  }) : messages = List.unmodifiable(messages);

  final AiConnectionProfile connectionProfile;
  final String conversationId;
  final List<AiChatMessage> messages;
  final String? systemInstruction;
}
