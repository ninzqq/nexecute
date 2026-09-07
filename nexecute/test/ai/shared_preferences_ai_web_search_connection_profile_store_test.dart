import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'persists profiles and active selection without credential values',
    () async {
      final profile = AiWebSearchConnectionProfile(
        id: 'brave',
        name: 'Brave Search',
        providerKind: AiWebSearchProviderKind.brave,
        baseUrl: AiWebSearchProviderCatalog.brave.trustedBaseUri!,
        enabled: true,
        credentialReference: 'secure-storage:opaque',
      );
      final first = SharedPreferencesAiWebSearchConnectionProfileStore();
      await first.saveProfile(profile);
      await first.setActiveProfileId(profile.id);
      first.dispose();

      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getKeys(),
        contains('ai_web_search_connection_profiles_v1'),
      );
      expect(
        preferences.getKeys(),
        contains('ai_active_web_search_connection_profile_id_v1'),
      );

      final reopened = SharedPreferencesAiWebSearchConnectionProfileStore();
      addTearDown(reopened.dispose);
      expect((await reopened.getProfiles()).single.id, profile.id);
      expect((await reopened.getActiveProfile())?.id, profile.id);
    },
  );
}
