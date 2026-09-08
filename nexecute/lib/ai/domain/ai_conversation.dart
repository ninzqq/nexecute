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
  }) : messages = List.unmodifiable(_orderedMessages(messages)),
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

List<AiChatMessage> _orderedMessages(List<AiChatMessage> messages) {
  final indexed = messages.indexed.toList();
  indexed.sort((left, right) {
    final leftSequence = left.$2.sequence;
    final rightSequence = right.$2.sequence;
    if (leftSequence != null &&
        rightSequence != null &&
        leftSequence != rightSequence) {
      return leftSequence.compareTo(rightSequence);
    }
    final timestamp = left.$2.createdAt.compareTo(right.$2.createdAt);
    return timestamp != 0 ? timestamp : left.$1.compareTo(right.$1);
  });
  return [for (final entry in indexed) entry.$2];
}
