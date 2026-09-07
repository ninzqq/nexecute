import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  test(
    'stores and removes a Brave key separately from profile metadata',
    () async {
      final profiles = InMemoryAiWebSearchConnectionProfileStore();
      final credentials = FakeAiCredentialStore();
      final controller = AiWebSearchSettingsController(
        profileStore: profiles,
        searchRepository: const UnavailableAiWebSearchRepository(),
        credentialStore: credentials,
        idFactory: () => 'brave',
        isWeb: false,
      );
      addTearDown(profiles.dispose);
      addTearDown(controller.dispose);
      await controller.initialize();

      await controller.saveProfile(
        AiWebSearchConnectionProfile(
          id: controller.createProfileId(),
          name: 'Brave Search',
          providerKind: AiWebSearchProviderKind.brave,
          baseUrl: AiWebSearchProviderCatalog.brave.trustedBaseUri!,
          enabled: true,
        ),
        credential: 'brave-secret',
      );

      final saved = controller.profiles.single;
      expect(saved.credentialReference, startsWith('secure-storage:'));
      expect(saved.toString(), isNot(contains('brave-secret')));
      expect(credentials.savedCredentials, ['brave-secret']);
      expect(controller.activeProfile?.id, saved.id);

      await controller.deleteProfile(saved.id);

      expect(controller.profiles, isEmpty);
      expect(credentials.credentials, isEmpty);
    },
  );

  test('rejects enabled reusable credentials in a web build', () async {
    final profiles = InMemoryAiWebSearchConnectionProfileStore();
    final controller = AiWebSearchSettingsController(
      profileStore: profiles,
      searchRepository: const UnavailableAiWebSearchRepository(),
      credentialStore: FakeAiCredentialStore(),
      isWeb: true,
    );
    addTearDown(profiles.dispose);
    addTearDown(controller.dispose);
    await controller.initialize();

    await expectLater(
      controller.saveProfile(
        AiWebSearchConnectionProfile(
          id: 'brave',
          name: 'Brave Search',
          providerKind: AiWebSearchProviderKind.brave,
          baseUrl: AiWebSearchProviderCatalog.brave.trustedBaseUri!,
          enabled: true,
        ),
        credential: 'brave-secret',
      ),
      throwsFormatException,
    );
    expect(await profiles.getProfiles(), isEmpty);
  });
}
