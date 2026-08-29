import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  final profile = AiConnectionProfile(
    id: 'home',
    name: 'Home model',
    protocol: AiProtocol.openAiCompatibleChat,
    baseUrl: Uri.parse('https://ai.example.test/v1'),
    modelId: 'local-model',
  );

  test('fake repository records provider-neutral operations', () async {
    final repository = FakeAiAssistantRepository(
      models: [AiModelInfo(id: 'local-model')],
      responseEvents: const [
        AiTextDelta('Hello'),
        AiResponseCompleted(finishReason: 'stop'),
      ],
    );
    final request = AiChatRequest(
      connectionProfile: profile,
      conversationId: 'conversation-1',
      messages: [
        AiChatMessage(
          id: 'message-1',
          role: AiMessageRole.user,
          content: 'Hello',
          createdAt: DateTime(2026, 8, 29),
        ),
      ],
    );

    final result = await repository.testConnection(profile);
    final models = await repository.listModels(profile);
    final handle = await repository.startResponse(request);
    final events = await handle.events.toList();
    await handle.cancel();

    expect(result.isConnected, isTrue);
    expect(models.single.id, 'local-model');
    expect(repository.testedProfiles, [same(profile)]);
    expect(repository.listedProfiles, [same(profile)]);
    expect(repository.startedRequests, [same(request)]);
    expect(events.first, isA<AiTextDelta>());
    expect(repository.cancellationCount, 1);
  });

  test('unconfigured repository fails without accessing the network', () async {
    const repository = UnconfiguredAiAssistantRepository();
    final result = await repository.testConnection(profile);
    final handle = await repository.startResponse(
      AiChatRequest(
        connectionProfile: profile,
        conversationId: 'conversation-1',
        messages: const [],
      ),
    );
    final events = await handle.events.toList();

    expect(result.status, AiConnectionStatus.invalidConfiguration);
    expect(events.single, isA<AiResponseFailed>());
  });
}
