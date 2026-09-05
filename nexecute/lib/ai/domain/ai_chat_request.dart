import 'package:nexecute/ai/domain/ai_application_context.dart';
import 'package:nexecute/ai/domain/ai_chat_message.dart';
import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/ai/domain/ai_skill_invocation.dart';
import 'package:nexecute/ai/domain/ai_tool.dart';

class AiChatRequest {
  AiChatRequest({
    required this.connectionProfile,
    required this.conversationId,
    required List<AiChatMessage> messages,
    this.systemInstruction,
    this.applicationContext,
    this.readToolAuthorization,
    List<AiResolvedSkillInvocation> resolvedSkills = const [],
    List<AiToolContinuationMessage> continuationMessages = const [],
  }) : messages = List.unmodifiable(messages),
       resolvedSkills = List.unmodifiable(resolvedSkills),
       continuationMessages = List.unmodifiable(continuationMessages);

  final AiConnectionProfile connectionProfile;
  final String conversationId;
  final List<AiChatMessage> messages;
  final String? systemInstruction;

  /// Explicit, request-scoped application data. This is deliberately separate
  /// from [messages] so conversation stores cannot persist it by accident.
  final AiApplicationContextEnvelope? applicationContext;
  final AiReadToolAuthorization? readToolAuthorization;
  final List<AiResolvedSkillInvocation> resolvedSkills;
  final List<AiToolContinuationMessage> continuationMessages;

  /// Prompt-only supporting skills are neutral; declarations are combined into
  /// one request allow-list. If active skills declare nothing, no tools are
  /// exposed. Skill-free chat retains the ordinary authorized read workflow.
  Set<String>? get skillCapabilityAllowList =>
      resolvedSkills.isEmpty
          ? null
          : {for (final skill in resolvedSkills) ...skill.capabilities};

  List<AiToolDefinition> get toolDefinitions =>
      AiReadCapabilityRegistry.definitionsFor(
        profile: connectionProfile,
        authorization: readToolAuthorization,
        skillAllowList: skillCapabilityAllowList,
      );
}
