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
    expect(restored.capabilityOverrides, profile.capabilityOverrides);
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
