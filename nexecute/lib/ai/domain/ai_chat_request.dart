import 'package:nexecute/ai/domain/ai_application_context.dart';
import 'package:nexecute/ai/domain/ai_chat_message.dart';
import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/ai/domain/ai_tool.dart';

class AiChatRequest {
  AiChatRequest({
    required this.connectionProfile,
    required this.conversationId,
    required List<AiChatMessage> messages,
    this.systemInstruction,
    this.applicationContext,
    this.readToolAuthorization,
    List<AiToolContinuationMessage> continuationMessages = const [],
  }) : messages = List.unmodifiable(messages),
       continuationMessages = List.unmodifiable(continuationMessages);

  final AiConnectionProfile connectionProfile;
  final String conversationId;
  final List<AiChatMessage> messages;
  final String? systemInstruction;

  /// Explicit, request-scoped application data. This is deliberately separate
  /// from [messages] so conversation stores cannot persist it by accident.
  final AiApplicationContextEnvelope? applicationContext;
  final AiReadToolAuthorization? readToolAuthorization;
  final List<AiToolContinuationMessage> continuationMessages;

  List<AiToolDefinition> get toolDefinitions =>
      AiReadToolCatalog.definitionsFor(
        profile: connectionProfile,
        authorization: readToolAuthorization,
      );
}
