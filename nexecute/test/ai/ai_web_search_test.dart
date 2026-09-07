import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  AiWebSearchConnectionProfile searchProfile({
    bool enabled = true,
    String? credentialReference = 'secure-storage:brave',
  }) => AiWebSearchConnectionProfile(
    id: 'brave',
    name: 'Brave Search',
    providerKind: AiWebSearchProviderKind.brave,
    baseUrl: AiWebSearchProviderCatalog.brave.trustedBaseUri!,
    enabled: enabled,
    credentialReference: credentialReference,
  );

  AiConnectionProfile modelProfile({bool tools = true}) => AiConnectionProfile(
    id: 'model',
    name: 'Model',
    protocol: AiProtocol.openAiCompatibleChat,
    baseUrl: Uri.parse('https://model.example/v1'),
    modelId: 'model',
    capabilityOverrides: {AiCapability.tools: tools},
  );

  test('defines a fixed trusted Brave connection outside model profiles', () {
    final profile = searchProfile();

    expect(profile.isValid, isTrue);
    expect(profile.canSendRequests(isWeb: false), isTrue);
    expect(profile.canSendRequests(isWeb: true), isFalse);
    expect(
      profile
          .copyWith(baseUrl: Uri.parse('https://example.test/search'))
          .isValid,
      isFalse,
    );
    expect(searchProfile(credentialReference: null).isValid, isFalse);
  });

  test('validates bounded search requests and per-turn accounting', () {
    expect(
      AiWebSearchRequest(query: 'Suomen uutiset', resultLimit: 5).query,
      'Suomen uutiset',
    );
    expect(() => AiWebSearchRequest(query: 'one\ntwo'), throwsArgumentError);
    expect(
      () => AiWebSearchRequest(query: List.filled(51, 'word').join(' ')),
      throwsArgumentError,
    );
    expect(
      () => AiWebSearchRequest(query: 'query', resultLimit: 6),
      throwsArgumentError,
    );

    final budget = AiWebSearchTurnBudget();
    for (var index = 0; index < aiWebSearchMaxCallsPerTurn; index++) {
      budget.reserveCall();
    }
    expect(budget.reserveCall, throwsStateError);
    budget.recordContextCharacters(aiWebSearchMaxContextCharacters);
    expect(() => budget.recordContextCharacters(1), throwsStateError);
  });

  test('exposes search only at the complete authorization intersection', () {
    final search = searchProfile();
    final model = modelProfile();
    final authorization = AiWebSearchAuthorization(
      connectionProfileId: search.id,
    );

    List<AiToolDefinition> definitions({
      AiConnectionProfile? selectedModel,
      AiWebSearchConnectionProfile? selectedSearch,
      AiWebSearchAuthorization? selectedAuthorization,
      bool executorAvailable = true,
      Set<String>? skillAllowList = const {'searchWeb'},
      bool isWeb = false,
    }) => AiWebSearchToolCatalog.definitionsFor(
      modelProfile: selectedModel ?? model,
      executorAvailable: executorAvailable,
      searchProfile: selectedSearch ?? search,
      authorization: selectedAuthorization ?? authorization,
      skillAllowList: skillAllowList,
      isWeb: isWeb,
    );

    expect(definitions().single.name, AiWebSearchToolNames.searchWeb);
    expect(definitions(executorAvailable: false), isEmpty);
    expect(definitions(selectedModel: modelProfile(tools: false)), isEmpty);
    expect(definitions(selectedSearch: searchProfile(enabled: false)), isEmpty);
    expect(
      AiWebSearchToolCatalog.definitionsFor(
        modelProfile: model,
        executorAvailable: true,
        searchProfile: search,
        skillAllowList: const {'searchWeb'},
        isWeb: false,
      ),
      isEmpty,
    );
    expect(
      definitions(
        selectedAuthorization: const AiWebSearchAuthorization(
          connectionProfileId: 'different',
        ),
      ),
      isEmpty,
    );
    expect(definitions(skillAllowList: const {'listTasks'}), isEmpty);
    expect(definitions(isWeb: true), isEmpty);
  });

  test('searchWeb requires skill schema 4', () {
    expect(
      AiSkill(
        id: 'web-research',
        name: 'Web research',
        description: 'Research current public information.',
        instructions: 'Search only when the user authorizes it.',
        capabilities: const {'searchWeb'},
        createdAt: DateTime.utc(2026, 9, 7),
        updatedAt: DateTime.utc(2026, 9, 7),
      ).schemaVersion,
      4,
    );
    expect(
      () => AiSkill(
        schemaVersion: 3,
        id: 'legacy-web-research',
        name: 'Legacy web research',
        description: 'An invalid legacy declaration.',
        instructions: 'Search the web.',
        capabilities: const {'searchWeb'},
        createdAt: DateTime.utc(2026, 9, 7),
        updatedAt: DateTime.utc(2026, 9, 7),
      ),
      throwsFormatException,
    );
  });
}
