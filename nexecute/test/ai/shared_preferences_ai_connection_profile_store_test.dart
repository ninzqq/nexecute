import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists profiles and the active selection across instances', () async {
    final firstStore = SharedPreferencesAiConnectionProfileStore();
    final profile = AiConnectionProfile(
      id: 'home',
      name: 'Home Ollama',
      protocol: AiProtocol.openAiCompatibleChat,
      baseUrl: Uri.parse('https://ai.example.test/v1'),
      modelId: 'qwen3:8b',
      capabilityOverrides: const {AiCapability.tools: false},
    );
    await firstStore.saveProfile(profile);
    await firstStore.setActiveProfileId(profile.id);
    firstStore.dispose();

    final restoredStore = SharedPreferencesAiConnectionProfileStore();
    addTearDown(restoredStore.dispose);
    final restoredProfiles = await restoredStore.getProfiles();
    final restoredActive = await restoredStore.getActiveProfile();

    expect(restoredProfiles, hasLength(1));
    expect(restoredProfiles.single.name, profile.name);
    expect(restoredProfiles.single.protocol, profile.protocol);
    expect(restoredProfiles.single.baseUrl, profile.baseUrl);
    expect(restoredProfiles.single.modelId, profile.modelId);
    expect(
      restoredProfiles.single.capabilityOverrides[AiCapability.tools],
      isFalse,
    );
    expect(restoredActive?.id, profile.id);
  });

  test('deleting the active profile also clears its selection', () async {
    final store = SharedPreferencesAiConnectionProfileStore();
    addTearDown(store.dispose);
    final profile = _profile();
    await store.saveProfile(profile);
    await store.setActiveProfileId(profile.id);

    await store.deleteProfile(profile.id);

    expect(await store.getProfiles(), isEmpty);
    expect(await store.getActiveProfile(), isNull);
  });

  test('loads lazily and reports corrupted profile data', () async {
    SharedPreferences.setMockInitialValues({
      'ai_connection_profiles_v1': '{not-json',
    });
    final store = SharedPreferencesAiConnectionProfileStore();
    addTearDown(store.dispose);

    expect(store.getProfiles, throwsA(isA<FormatException>()));
  });
}

AiConnectionProfile _profile() {
  return AiConnectionProfile(
    id: 'home',
    name: 'Home Ollama',
    protocol: AiProtocol.openAiCompatibleChat,
    baseUrl: Uri.parse('https://ai.example.test/v1'),
    modelId: 'qwen3:8b',
  );
}
