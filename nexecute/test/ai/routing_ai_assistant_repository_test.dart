import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  test('routes a profile to its protocol adapter', () async {
    final adapter = FakeAiAssistantRepository(
      models: [AiModelInfo(id: 'local-model')],
    );
    final repository = RoutingAiAssistantRepository(
      adapters: {AiProtocol.openAiCompatibleChat: adapter},
      isWeb: false,
    );
    final profile = _customProfile();

    expect((await repository.testConnection(profile)).isConnected, isTrue);
    expect((await repository.listModels(profile)).single.id, 'local-model');
    final handle = await repository.startResponse(_request(profile));
    await handle.events.toList();

    expect(adapter.testedProfiles, [same(profile)]);
    expect(adapter.listedProfiles, [same(profile)]);
    expect(adapter.startedRequests.single.connectionProfile, same(profile));
  });

  test('blocks a hosted profile until cloud requests are enabled', () async {
    final adapter = FakeAiAssistantRepository();
    final repository = RoutingAiAssistantRepository(
      adapters: {AiProtocol.openAiCompatibleChat: adapter},
      isWeb: false,
    );
    final profile = _geminiProfile(hostedInferenceEnabled: false);

    final result = await repository.testConnection(profile);
    final handle = await repository.startResponse(_request(profile));
    final events = await handle.events.toList();

    expect(result.status, AiConnectionStatus.invalidConfiguration);
    expect(result.message, contains('disabled'));
    expect(events.single, isA<AiResponseFailed>());
    expect(adapter.testedProfiles, isEmpty);
    expect(adapter.startedRequests, isEmpty);
  });

  test('blocks direct hosted credentials on Web', () async {
    final adapter = FakeAiAssistantRepository();
    final repository = RoutingAiAssistantRepository(
      adapters: {AiProtocol.openAiCompatibleChat: adapter},
      isWeb: true,
    );

    final result = await repository.testConnection(
      _geminiProfile(hostedInferenceEnabled: true),
    );

    expect(result.status, AiConnectionStatus.invalidConfiguration);
    expect(result.message, contains('unavailable on Web'));
    expect(adapter.testedProfiles, isEmpty);
  });

  test('reports a missing protocol adapter without routing', () async {
    final repository = RoutingAiAssistantRepository(
      adapters: const {},
      isWeb: false,
    );
    final descriptor = AiProviderCatalog.openAI;
    final profile = AiConnectionProfile(
      id: 'openai',
      name: 'OpenAI',
      providerKind: descriptor.kind,
      protocol: descriptor.protocol,
      baseUrl: descriptor.trustedBaseUri!,
      modelId: 'model-id',
      authenticationMode: descriptor.authenticationMode,
      credentialReference: 'secure:credential',
      hostedInferenceEnabled: true,
    );

    final result = await repository.testConnection(profile);

    expect(result.status, AiConnectionStatus.unsupported);
    expect(result.message, contains('not implemented yet'));
  });
}

AiConnectionProfile _customProfile() => AiConnectionProfile(
  id: 'local',
  name: 'Local',
  protocol: AiProtocol.openAiCompatibleChat,
  baseUrl: Uri.parse('http://localhost:11434/v1'),
  modelId: 'local-model',
);

AiConnectionProfile _geminiProfile({required bool hostedInferenceEnabled}) {
  final descriptor = AiProviderCatalog.googleGemini;
  return AiConnectionProfile(
    id: 'gemini',
    name: 'Gemini',
    providerKind: descriptor.kind,
    protocol: descriptor.protocol,
    baseUrl: descriptor.trustedBaseUri!,
    modelId: 'model-id',
    authenticationMode: descriptor.authenticationMode,
    credentialReference: 'secure:credential',
    hostedInferenceEnabled: hostedInferenceEnabled,
  );
}

AiChatRequest _request(AiConnectionProfile profile) => AiChatRequest(
  connectionProfile: profile,
  conversationId: 'conversation',
  messages: const [],
);
