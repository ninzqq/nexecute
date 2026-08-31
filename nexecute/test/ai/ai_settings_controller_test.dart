import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  test('manages profile CRUD and active selection through the store', () async {
    final store = FakeAiConnectionProfileStore();
    addTearDown(store.dispose);
    final repository = FakeAiAssistantRepository();
    final credentialStore = FakeAiCredentialStore();
    final ids = ['copy-id'].iterator;
    final controller = AiSettingsController(
      profileStore: store,
      assistantRepository: repository,
      credentialStore: credentialStore,
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
    final credentialStore = FakeAiCredentialStore();
    final controller = AiSettingsController(
      profileStore: store,
      assistantRepository: repository,
      credentialStore: credentialStore,
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
    final credentialStore = FakeAiCredentialStore();
    final controller = AiSettingsController(
      profileStore: store,
      assistantRepository: repository,
      credentialStore: credentialStore,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    final invalid = _profile().copyWith(baseUrl: Uri.parse('relative'));

    final result = await controller.testConnection(invalid);

    expect(result.status, AiConnectionStatus.invalidConfiguration);
    expect(result.diagnostic?.kind, AiDiagnosticKind.invalidConfiguration);
    expect(repository.testedProfiles, isEmpty);
  });

  test('exposes a user-safe model-discovery diagnostic', () async {
    final diagnostic = AiDiagnostic(
      kind: AiDiagnosticKind.authentication,
      title: 'Authentication failed',
      summary: 'The endpoint rejected the configured authentication.',
      suggestions: const ['Check the credential in AI Settings.'],
    );
    final store = FakeAiConnectionProfileStore(profiles: [_profile()]);
    addTearDown(store.dispose);
    final controller = AiSettingsController(
      profileStore: store,
      assistantRepository: FakeAiAssistantRepository(
        listModelsError: AiDiagnosticException(
          diagnostic: diagnostic,
          cause: StateError('secret raw failure'),
        ),
      ),
      credentialStore: FakeAiCredentialStore(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    final models = await controller.discoverModels(_profile());

    expect(models, isEmpty);
    expect(controller.modelDiscoveryDiagnostic, same(diagnostic));
    expect(controller.modelDiscoveryError, diagnostic.summary);
    expect(
      controller.modelDiscoveryError.toString(),
      isNot(contains('secret')),
    );
  });

  test('stores, replaces, and removes bearer tokens separately', () async {
    final store = FakeAiConnectionProfileStore();
    addTearDown(store.dispose);
    final credentialStore = FakeAiCredentialStore();
    final controller = AiSettingsController(
      profileStore: store,
      assistantRepository: FakeAiAssistantRepository(),
      credentialStore: credentialStore,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    final bearerProfile = _profile().copyWith(
      authenticationMode: AiAuthenticationMode.bearerToken,
      clearCredentialReference: true,
    );

    await controller.saveProfile(bearerProfile, bearerToken: 'first-secret');
    final firstSaved = controller.profiles.single;
    final firstReference = firstSaved.credentialReference!;

    expect(firstReference, startsWith('secure-storage:'));
    expect(credentialStore.credentials[firstReference], 'first-secret');

    await controller.saveProfile(firstSaved, bearerToken: 'second-secret');
    final secondSaved = controller.profiles.single;
    final secondReference = secondSaved.credentialReference!;

    expect(secondReference, isNot(firstReference));
    expect(credentialStore.credentials[firstReference], isNull);
    expect(credentialStore.credentials[secondReference], 'second-secret');
    expect(credentialStore.deletedReferences, contains(firstReference));

    await controller.saveProfile(
      secondSaved.copyWith(authenticationMode: AiAuthenticationMode.none),
    );

    expect(controller.profiles.single.credentialReference, isNull);
    expect(credentialStore.credentials[secondReference], isNull);
    expect(credentialStore.deletedReferences, contains(secondReference));
  });

  test('never copies a credential and deletes it with its profile', () async {
    final credentialStore = FakeAiCredentialStore(
      credentials: const {'secure-storage:original': 'private-token'},
    );
    final original = _profile().copyWith(
      authenticationMode: AiAuthenticationMode.bearerToken,
      credentialReference: 'secure-storage:original',
    );
    final store = FakeAiConnectionProfileStore(profiles: [original]);
    addTearDown(store.dispose);
    final controller = AiSettingsController(
      profileStore: store,
      assistantRepository: FakeAiAssistantRepository(),
      credentialStore: credentialStore,
      idFactory: () => 'copy-id',
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    final duplicate = await controller.duplicateProfile(original);

    expect(duplicate.authenticationMode, AiAuthenticationMode.bearerToken);
    expect(duplicate.credentialReference, isNull);
    expect(credentialStore.credentials, hasLength(1));

    await controller.deleteProfile(original.id);

    expect(credentialStore.credentials, isEmpty);
    expect(
      credentialStore.deletedReferences,
      contains('secure-storage:original'),
    );
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
