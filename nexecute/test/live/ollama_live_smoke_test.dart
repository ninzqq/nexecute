import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

const _baseUrl = String.fromEnvironment('NEXECUTE_OLLAMA_BASE_URL');
const _modelId = String.fromEnvironment('NEXECUTE_OLLAMA_MODEL');

void main() {
  final isConfigured = _baseUrl.isNotEmpty && _modelId.isNotEmpty;

  test(
    'discovers the configured Ollama model and streams a real response',
    () async {
      final repository = OpenAiCompatibleAssistantRepository(
        connectionTimeout: const Duration(seconds: 30),
      );
      addTearDown(repository.dispose);
      final profile = AiConnectionProfile(
        id: 'live-ollama-smoke-test',
        name: 'Live Ollama smoke test',
        protocol: AiProtocol.openAiCompatibleChat,
        baseUrl: Uri.parse(_baseUrl),
        modelId: _modelId,
      );

      final result = await repository.testConnection(profile);
      expect(
        result.status,
        AiConnectionStatus.connected,
        reason: result.message,
      );

      final models = await repository.listModels(profile);
      expect(
        models.map((model) => model.id),
        contains(_modelId),
        reason: 'The configured model must be present in GET /v1/models.',
      );

      final handle = await repository.startResponse(
        AiChatRequest(
          connectionProfile: profile,
          conversationId: 'live-smoke-test',
          messages: [
            AiChatMessage(
              id: 'live-smoke-test-user-message',
              role: AiMessageRole.user,
              content:
                  'Reply with a short greeting. Do not use tools or external data.',
              createdAt: DateTime.now(),
            ),
          ],
        ),
      );
      final events =
          await handle.events.timeout(const Duration(minutes: 2)).toList();
      final failures = events.whereType<AiResponseFailed>().toList();
      final responseText =
          events.whereType<AiTextDelta>().map((event) => event.text).join();

      expect(failures, isEmpty, reason: failures.firstOrNull?.message);
      expect(responseText.trim(), isNotEmpty);
      expect(events.whereType<AiResponseCompleted>(), isNotEmpty);
    },
    skip:
        isConfigured
            ? false
            : 'Set NEXECUTE_OLLAMA_BASE_URL and NEXECUTE_OLLAMA_MODEL.',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
