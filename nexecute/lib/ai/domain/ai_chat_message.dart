import 'package:nexecute/ai/domain/ai_diagnostic.dart';

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
    this.diagnostic,
    this.toolCallId,
  });

  final String id;
  final AiMessageRole role;
  final String content;
  final DateTime createdAt;
  final AiMessageStatus status;
  final String? errorMessage;
  final AiDiagnostic? diagnostic;
  final String? toolCallId;

  AiChatMessage copyWith({
    String? id,
    AiMessageRole? role,
    String? content,
    DateTime? createdAt,
    AiMessageStatus? status,
    String? errorMessage,
    AiDiagnostic? diagnostic,
    String? toolCallId,
  }) {
    return AiChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      diagnostic: diagnostic ?? this.diagnostic,
      toolCallId: toolCallId ?? this.toolCallId,
    );
  }
}
