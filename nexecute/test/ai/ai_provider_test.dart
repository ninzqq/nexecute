import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  test('only Gemini adds its app-owned client-identification header', () {
    expect(AiProviderCatalog.custom.requestHeaders, isEmpty);
    expect(AiProviderCatalog.openAI.requestHeaders, isEmpty);
    expect(AiProviderCatalog.anthropic.requestHeaders, isEmpty);
    expect(AiProviderCatalog.googleGemini.requestHeaders, {
      'x-goog-api-client': nexecuteGeminiApiClient,
    });
  });

  test(
    'hosted provider presets pin protocol, authentication, and endpoint',
    () {
      for (final descriptor in AiProviderCatalog.values.where(
        (provider) => provider.hosted,
      )) {
        final profile = AiConnectionProfile(
          id: descriptor.kind.name,
          name: descriptor.label,
          providerKind: descriptor.kind,
          protocol: descriptor.protocol,
          baseUrl: descriptor.trustedBaseUri!,
          modelId: 'model-id',
          authenticationMode: descriptor.authenticationMode,
          credentialReference: 'secure:credential',
        );

        expect(profile.isValid, isTrue);
        expect(profile.hasTrustedProviderConfiguration, isTrue);
        expect(profile.canSendRequests(isWeb: false), isFalse);
        expect(profile.canSendRequests(isWeb: true), isFalse);
        expect(
          profile
              .copyWith(hostedInferenceEnabled: true)
              .canSendRequests(isWeb: false),
          isTrue,
        );
      }
    },
  );

  test('hosted provider rejects endpoint and protocol substitution', () {
    final descriptor = AiProviderCatalog.googleGemini;
    final profile = AiConnectionProfile(
      id: 'gemini',
      name: 'Gemini',
      providerKind: descriptor.kind,
      protocol: descriptor.protocol,
      baseUrl: Uri.parse('https://credential-thief.example/v1/'),
      modelId: 'model-id',
      authenticationMode: descriptor.authenticationMode,
      credentialReference: 'secure:credential',
      hostedInferenceEnabled: true,
    );

    expect(profile.isValid, isFalse);
    expect(profile.hasTrustedProviderConfiguration, isFalse);
  });

  test('hosted provider rejects query and user-info endpoint changes', () {
    final descriptor = AiProviderCatalog.googleGemini;

    expect(
      descriptor.matchesTrustedConfiguration(
        candidateProtocol: descriptor.protocol,
        candidateAuthenticationMode: descriptor.authenticationMode,
        candidateBaseUrl: Uri.parse(
          '${descriptor.trustedBaseUrl}?redirect=unexpected',
        ),
      ),
      isFalse,
    );
    expect(
      descriptor.matchesTrustedConfiguration(
        candidateProtocol: descriptor.protocol,
        candidateAuthenticationMode: descriptor.authenticationMode,
        candidateBaseUrl: Uri.parse(
          'https://user@generativelanguage.googleapis.com/v1beta/openai/',
        ),
      ),
      isFalse,
    );
  });
}
