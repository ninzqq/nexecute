import 'package:nexecute/ai/domain/ai_chat_request.dart';
import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/ai/domain/ai_connection_result.dart';
import 'package:nexecute/ai/domain/ai_model_info.dart';
import 'package:nexecute/ai/repositories/ai_response_handle.dart';

abstract interface class AiAssistantRepository {
  Future<AiConnectionResult> testConnection(AiConnectionProfile profile);

  Future<List<AiModelInfo>> listModels(AiConnectionProfile profile);

  Future<AiResponseHandle> startResponse(AiChatRequest request);
}
