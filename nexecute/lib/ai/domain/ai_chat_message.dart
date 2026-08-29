enum AiMessageRole { system, user, assistant, tool }

enum AiMessageStatus { complete, streaming, cancelled, failed }

class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.status = AiMessageStatus.complete,
    this.errorMessage,
    this.toolCallId,
  });

  final String id;
  final AiMessageRole role;
  final String content;
  final DateTime createdAt;
  final AiMessageStatus status;
  final String? errorMessage;
  final String? toolCallId;

  AiChatMessage copyWith({
    String? id,
    AiMessageRole? role,
    String? content,
    DateTime? createdAt,
    AiMessageStatus? status,
    String? errorMessage,
    String? toolCallId,
  }) {
    return AiChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      toolCallId: toolCallId ?? this.toolCallId,
    );
  }
}
