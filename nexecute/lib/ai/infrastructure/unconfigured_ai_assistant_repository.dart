import 'package:nexecute/ai/domain/ai_chat_request.dart';
import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/ai/domain/ai_connection_result.dart';
import 'package:nexecute/ai/domain/ai_model_info.dart';
import 'package:nexecute/ai/domain/ai_stream_event.dart';
import 'package:nexecute/ai/repositories/ai_assistant_repository.dart';
import 'package:nexecute/ai/repositories/ai_response_handle.dart';

class UnconfiguredAiAssistantRepository implements AiAssistantRepository {
  const UnconfiguredAiAssistantRepository();

  static const _message = 'No AI endpoint adapter is configured yet.';

  @override
  Future<AiConnectionResult> testConnection(
    AiConnectionProfile profile,
  ) async => const AiConnectionResult(
    status: AiConnectionStatus.invalidConfiguration,
    message: _message,
  );

  @override
  Future<List<AiModelInfo>> listModels(AiConnectionProfile profile) async =>
      const [];

  @override
  Future<AiResponseHandle> startResponse(AiChatRequest request) async {
    final error = StateError(_message);
    return StreamAiResponseHandle(
      events: Stream.value(
        AiResponseFailed(error: error, message: _message, retryable: false),
      ),
      onCancel: () async {},
    );
  }
}
