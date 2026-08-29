import 'package:nexecute/ai/domain/ai_chat_message.dart';

class AiConversation {
  AiConversation({
    required this.id,
    required this.title,
    required this.connectionProfileId,
    required this.modelId,
    required this.createdAt,
    required this.updatedAt,
    List<AiChatMessage> messages = const [],
  }) : messages = List.unmodifiable(messages);

  final String id;
  final String title;
  final String connectionProfileId;
  final String modelId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AiChatMessage> messages;

  AiConversation copyWith({
    String? id,
    String? title,
    String? connectionProfileId,
    String? modelId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AiChatMessage>? messages,
  }) {
    return AiConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      connectionProfileId: connectionProfileId ?? this.connectionProfileId,
      modelId: modelId ?? this.modelId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }
}
