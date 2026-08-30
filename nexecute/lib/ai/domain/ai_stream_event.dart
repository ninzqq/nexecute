import 'package:nexecute/ai/domain/ai_tool.dart';

sealed class AiStreamEvent {
  const AiStreamEvent();
}

final class AiTextDelta extends AiStreamEvent {
  const AiTextDelta(this.text);

  final String text;
}

final class AiReasoningDelta extends AiStreamEvent {
  const AiReasoningDelta(this.text);

  final String text;
}

final class AiToolCallRequested extends AiStreamEvent {
  AiToolCallRequested({
    required String id,
    required String name,
    required Map<String, Object?> arguments,
  }) : call = AiToolCall(id: id, name: name, arguments: arguments);

  AiToolCallRequested.fromCall(this.call);

  final AiToolCall call;

  String get id => call.id;
  String get name => call.name;
  Map<String, Object?> get arguments => call.arguments;
}

class AiTokenUsage {
  const AiTokenUsage({
    required this.inputTokens,
    required this.outputTokens,
    this.totalTokens,
  });

  final int inputTokens;
  final int outputTokens;
  final int? totalTokens;
}

final class AiResponseCompleted extends AiStreamEvent {
  const AiResponseCompleted({this.finishReason, this.usage});

  final String? finishReason;
  final AiTokenUsage? usage;
}

final class AiResponseFailed extends AiStreamEvent {
  const AiResponseFailed({
    required this.error,
    required this.message,
    this.code,
    this.retryable = false,
  });

  final Object error;
  final String message;
  final String? code;
  final bool retryable;
}
