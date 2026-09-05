import 'dart:convert';

import 'package:nexecute/ai/domain/ai_chat_message.dart';
import 'package:nexecute/ai/domain/ai_chat_request.dart';
import 'package:nexecute/ai/domain/ai_tool.dart';

final class AiRequestBudgetException implements Exception {
  const AiRequestBudgetException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Conservative provider-neutral accounting: one token per UTF-8 byte plus
/// framing margins. No tokenizer or model context size is inferred from a name.
abstract final class AiRequestBudget {
  static const maxHistoryMessages = 24;
  static const maxCombinedSkillCharacters = 32000;
  static const framingReserve = 1024;
  static const toolContinuationReserve = 2048;

  static List<AiChatMessage> history(List<AiChatMessage> messages) {
    final complete =
        messages.where((m) => m.status == AiMessageStatus.complete).toList();
    if (complete.length <= maxHistoryMessages) {
      return List.unmodifiable(complete);
    }
    var start = complete.length - maxHistoryMessages;
    // Keep whole turns, never an orphan assistant response.
    while (start < complete.length - 1 &&
        complete[start].role != AiMessageRole.user) {
      start++;
    }
    return List.unmodifiable(complete.sublist(start));
  }

  static int estimate(
    AiChatRequest request, {
    bool reserveContinuation = true,
  }) {
    var bytes = framingReserve + request.connectionProfile.maxOutputTokens;
    bytes += utf8.encode(request.systemInstruction ?? '').length;
    for (final message in request.messages) {
      bytes += utf8.encode(message.content).length + 64;
    }
    if (request.applicationContext case final context?) {
      bytes += utf8.encode(context.encode()).length + 512;
    }
    for (final tool in request.toolDefinitions) {
      bytes +=
          utf8
              .encode(
                jsonEncode({
                  'name': tool.name,
                  'description': tool.description,
                  'parameters': tool.parameters.toJson(),
                }),
              )
              .length +
          128;
    }
    for (final continuation in request.continuationMessages) {
      bytes += 128;
      switch (continuation) {
        case AiAssistantToolCallMessage(:final content, :final calls):
          bytes += utf8.encode(content ?? '').length;
          for (final call in calls) {
            bytes +=
                utf8
                    .encode(
                      jsonEncode({
                        'id': call.id,
                        'name': call.name,
                        'arguments': call.arguments,
                      }),
                    )
                    .length +
                64;
          }
        case AiToolResultMessage(
          :final result,
          :final toolCallId,
          :final toolName,
        ):
          bytes +=
              utf8.encode(jsonEncode(result)).length +
              utf8.encode(toolCallId + toolName).length +
              64;
      }
    }
    if (reserveContinuation && request.toolDefinitions.isNotEmpty) {
      bytes += toolContinuationReserve;
    }
    return bytes;
  }

  static void validate(
    AiChatRequest request, {
    bool reserveContinuation = true,
  }) {
    if (request.resolvedSkills.length > 1 &&
        !request.connectionProfile.allowMultipleSkills) {
      throw const AiRequestBudgetException(
        'Multiple skills are experimental. Enable them for this connection in AI Settings after validating your model, or select one skill.',
      );
    }
    if (request.resolvedSkills.fold<int>(
          0,
          (n, s) => n + s.instructions.runes.length,
        ) >
        maxCombinedSkillCharacters) {
      throw const AiRequestBudgetException(
        'Active skills exceed the combined 32,000-character limit. Deactivate a skill or shorten its instructions.',
      );
    }
    final required = estimate(
      request,
      reserveContinuation: reserveContinuation,
    );
    if (required > request.connectionProfile.contextWindowTokens) {
      throw AiRequestBudgetException(
        'Request needs a conservative budget of $required tokens; this connection allows ${request.connectionProfile.contextWindowTokens}. Deactivate skills, reduce attachments/output, start a new conversation, or set the server’s verified context window in AI Settings. Nothing was truncated.',
      );
    }
  }
}
