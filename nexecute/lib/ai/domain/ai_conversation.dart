import 'package:nexecute/ai/domain/ai_chat_message.dart';
import 'package:nexecute/ai/domain/ai_skill_invocation.dart';

class AiConversation {
  AiConversation({
    required this.id,
    required this.title,
    required this.connectionProfileId,
    required this.modelId,
    required this.createdAt,
    required this.updatedAt,
    List<AiChatMessage> messages = const [],
    Iterable<AiSkillReference> activeSkills = const [],
  }) : messages = List.unmodifiable(messages),
       activeSkills = normalizeAiSkillReferences(activeSkills);

  final String id;
  final String title;
  final String connectionProfileId;
  final String modelId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AiChatMessage> messages;
  final List<AiSkillReference> activeSkills;

  AiConversation copyWith({
    String? id,
    String? title,
    String? connectionProfileId,
    String? modelId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AiChatMessage>? messages,
    Iterable<AiSkillReference>? activeSkills,
  }) {
    return AiConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      connectionProfileId: connectionProfileId ?? this.connectionProfileId,
      modelId: modelId ?? this.modelId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      activeSkills: activeSkills ?? this.activeSkills,
    );
  }
}
