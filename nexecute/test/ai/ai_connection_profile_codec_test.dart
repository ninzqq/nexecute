import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/ai/infrastructure/ai_connection_profile_codec.dart';

void main() {
  test('round-trips every connection profile field', () {
    final profile = AiConnectionProfile(
      id: 'profile-1',
      name: 'Private gateway',
      protocol: AiProtocol.nexecuteGateway,
      baseUrl: Uri.parse('https://gateway.example.test/ai'),
      modelId: 'model-1',
      authenticationMode: AiAuthenticationMode.gatewaySession,
      credentialReference: 'credential-1',
      reasoningEffort: AiReasoningEffort.high,
      maxOutputTokens: 2048,
      connectionTimeout: const Duration(seconds: 75),
      responseIdleTimeout: const Duration(seconds: 45),
      capabilityOverrides: const {
        AiCapability.modelDiscovery: false,
        AiCapability.tools: true,
      },
    );

    final restored = AiConnectionProfileCodec.fromMap(
      AiConnectionProfileCodec.toMap(profile),
    );

    expect(restored.id, profile.id);
    expect(restored.name, profile.name);
    expect(restored.protocol, profile.protocol);
    expect(restored.baseUrl, profile.baseUrl);
    expect(restored.modelId, profile.modelId);
    expect(restored.authenticationMode, profile.authenticationMode);
    expect(restored.credentialReference, profile.credentialReference);
    expect(restored.reasoningEffort, profile.reasoningEffort);
    expect(restored.maxOutputTokens, profile.maxOutputTokens);
    expect(restored.connectionTimeout, profile.connectionTimeout);
    expect(restored.responseIdleTimeout, profile.responseIdleTimeout);
    expect(restored.capabilityOverrides, profile.capabilityOverrides);
  });

  test('uses safe generation defaults for existing saved profiles', () {
    final restored = AiConnectionProfileCodec.fromMap({
      'id': 'legacy-profile',
      'name': 'Existing local AI',
      'protocol': 'openAiCompatibleChat',
      'baseUrl': 'http://ai.example.test/v1',
      'modelId': 'local-model',
      'authenticationMode': 'none',
    });

    expect(restored.reasoningEffort, AiReasoningEffort.automatic);
    expect(restored.maxOutputTokens, aiDefaultMaxOutputTokens);
    expect(restored.connectionTimeout, aiDefaultConnectionTimeout);
    expect(restored.responseIdleTimeout, aiDefaultResponseIdleTimeout);
  });

  test('rejects unknown enum values instead of guessing', () {
    expect(
      () => AiConnectionProfileCodec.fromMap({
        'id': 'profile-1',
        'name': 'Broken',
        'protocol': 'unknownProtocol',
        'baseUrl': 'https://example.test',
        'modelId': 'model-1',
        'authenticationMode': 'none',
      }),
      throwsFormatException,
    );
  });
}
