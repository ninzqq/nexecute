import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  test('manages profile CRUD and active selection through the store', () async {
    final store = FakeAiConnectionProfileStore();
    addTearDown(store.dispose);
    final repository = FakeAiAssistantRepository();
    final ids = ['copy-id'].iterator;
    final controller = AiSettingsController(
      profileStore: store,
      assistantRepository: repository,
      idFactory: () {
        ids.moveNext();
        return ids.current;
      },
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    final profile = _profile();

    await controller.saveProfile(profile);
    final duplicate = await controller.duplicateProfile(profile);
    await controller.selectProfile(duplicate.id);

    expect(controller.profiles, hasLength(2));
    expect(controller.activeProfile?.id, duplicate.id);
    expect(duplicate.id, 'copy-id');
    expect(duplicate.name, 'Home Ollama copy');

    await controller.deleteProfile(duplicate.id);

    expect(controller.profiles.single.id, profile.id);
    expect(controller.activeProfile, isNull);
  });

  test('exposes connection and model-discovery states', () async {
    final store = FakeAiConnectionProfileStore(profiles: [_profile()]);
    addTearDown(store.dispose);
    final repository = FakeAiAssistantRepository(
      connectionResult: const AiConnectionResult.connected(
        message: 'Ready',
        latency: Duration(milliseconds: 25),
      ),
      models: [AiModelInfo(id: 'qwen3:8b'), AiModelInfo(id: 'gemma4')],
    );
    final controller = AiSettingsController(
      profileStore: store,
      assistantRepository: repository,
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    final result = await controller.testConnection(_profile());
    final models = await controller.discoverModels(_profile());

    expect(result.isConnected, isTrue);
    expect(controller.connectionResult?.message, 'Ready');
    expect(controller.testingProfileId, isNull);
    expect(models.map((model) => model.id), ['qwen3:8b', 'gemma4']);
    expect(repository.testedProfiles.single.id, 'home');
    expect(repository.listedProfiles.single.id, 'home');
  });

  test('does not call a repository for an invalid profile', () async {
    final store = FakeAiConnectionProfileStore();
    addTearDown(store.dispose);
    final repository = FakeAiAssistantRepository();
    final controller = AiSettingsController(
      profileStore: store,
      assistantRepository: repository,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    final invalid = _profile().copyWith(baseUrl: Uri.parse('relative'));

    final result = await controller.testConnection(invalid);

    expect(result.status, AiConnectionStatus.invalidConfiguration);
    expect(repository.testedProfiles, isEmpty);
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
