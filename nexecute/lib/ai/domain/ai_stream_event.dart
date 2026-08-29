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
    required this.id,
    required this.name,
    required Map<String, Object?> arguments,
  }) : arguments = Map.unmodifiable(arguments);

  final String id;
  final String name;
  final Map<String, Object?> arguments;
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
