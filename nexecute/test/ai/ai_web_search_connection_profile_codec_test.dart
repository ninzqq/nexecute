import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/ai/infrastructure/ai_web_search_connection_profile_codec.dart';

void main() {
  test('round-trips profile metadata without the credential value', () {
    final profile = AiWebSearchConnectionProfile(
      id: 'brave',
      name: 'Brave Search',
      providerKind: AiWebSearchProviderKind.brave,
      baseUrl: AiWebSearchProviderCatalog.brave.trustedBaseUri!,
      enabled: true,
      credentialReference: 'secure-storage:opaque',
      country: 'FI',
      searchLanguage: 'fi',
      safeSearch: AiWebSearchSafeSearch.strict,
      requestTimeout: const Duration(seconds: 20),
    );

    final encoded = AiWebSearchConnectionProfileCodec.toMap(profile);
    final restored = AiWebSearchConnectionProfileCodec.fromMap(encoded);

    expect(encoded.toString(), isNot(contains('actual-secret')));
    expect(restored.id, profile.id);
    expect(restored.baseUrl, profile.baseUrl);
    expect(restored.credentialReference, profile.credentialReference);
    expect(restored.safeSearch, profile.safeSearch);
    expect(restored.requestTimeout, profile.requestTimeout);
  });

  test('rejects unknown fields and untrusted Brave endpoints', () {
    final valid = AiWebSearchConnectionProfileCodec.toMap(
      AiWebSearchConnectionProfile(
        id: 'brave',
        name: 'Brave Search',
        providerKind: AiWebSearchProviderKind.brave,
        baseUrl: AiWebSearchProviderCatalog.brave.trustedBaseUri!,
        credentialReference: 'secure-storage:opaque',
      ),
    );

    expect(
      () => AiWebSearchConnectionProfileCodec.fromMap({
        ...valid,
        'unexpected': true,
      }),
      throwsFormatException,
    );
    expect(
      () => AiWebSearchConnectionProfileCodec.fromMap({
        ...valid,
        'baseUrl': 'https://attacker.example/search',
      }),
      throwsFormatException,
    );
  });
}
