import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  late AiConnectionProfile modelProfile;
  late AiWebSearchConnectionProfile searchProfile;

  setUp(() {
    modelProfile = AiConnectionProfile(
      id: 'model',
      name: 'Tool model',
      protocol: AiProtocol.openAiCompatibleChat,
      baseUrl: Uri.parse('https://ai.example.test/v1'),
      modelId: 'model',
      capabilityOverrides: const {AiCapability.tools: true},
    );
    searchProfile = AiWebSearchConnectionProfile(
      id: 'brave',
      name: 'Brave',
      providerKind: AiWebSearchProviderKind.brave,
      baseUrl: AiWebSearchProviderCatalog.brave.trustedBaseUri!,
      enabled: true,
      credentialReference: 'secure-storage:key',
    );
  });

  test(
    'executes authorized web search and returns untrusted source data',
    () async {
      late FakeAiAssistantRepository assistant;
      assistant = FakeAiAssistantRepository(
        responseStreamBuilder: (_) {
          if (assistant.startedRequests.length == 1) {
            return Stream.fromIterable([
              AiToolCallRequested(
                id: 'search-1',
                name: AiWebSearchToolNames.searchWeb,
                arguments: const {
                  'query': 'Flutter current release',
                  'resultLimit': 2,
                  'freshness': 'week',
                },
              ),
              const AiResponseCompleted(finishReason: 'tool_calls'),
            ]);
          }
          return Stream.fromIterable(const [
            AiTextDelta('Flutter has a recent release.'),
            AiResponseCompleted(),
          ]);
        },
      );
      final search = _FakeSearchRepository([
        AiWebSearchResult(
          sourceId: 'provider-id',
          title: 'Flutter release',
          url: Uri.parse('https://flutter.dev/news'),
          snippet: 'Release details',
          providerName: 'Brave Search API',
          publishedAt: DateTime.utc(2026, 9, 6),
        ),
      ]);
      final coordinator = AiApplicationToolCoordinator(
        assistantRepository: assistant,
        webSearchRepository: search,
      );

      final handle = await coordinator.startResponse(
        _request(modelProfile, searchProfile),
      );
      final events = await handle.events.toList();

      expect(events.whereType<AiTextDelta>().single.text, contains('recent'));
      expect(search.requests.single.query, 'Flutter current release');
      expect(search.requests.single.freshness, AiWebSearchFreshness.week);
      final result =
          assistant.startedRequests.last.continuationMessages
              .whereType<AiToolResultMessage>()
              .single;
      expect(result.isError, isFalse);
      expect(result.result['dataClassification'], 'publicWebSearchResults');
      expect(result.result['securityNotice'], contains('untrusted'));
      expect(result.result.toString(), contains('web-1'));
      expect(result.result.toString(), isNot(contains('provider-id')));
    },
  );

  test('does not call search without matching request authorization', () async {
    late FakeAiAssistantRepository assistant;
    assistant = FakeAiAssistantRepository(
      responseStreamBuilder:
          (_) => Stream.fromIterable(const [AiResponseCompleted()]),
    );
    final search = _FakeSearchRepository(const []);
    final coordinator = AiApplicationToolCoordinator(
      assistantRepository: assistant,
      webSearchRepository: search,
    );
    final request = _request(modelProfile, searchProfile, authorize: false);

    final handle = await coordinator.startResponse(request);
    await handle.events.toList();

    expect(search.requests, isEmpty);
    expect(assistant.startedRequests.single.toolDefinitions, isEmpty);
  });

  test('limits web search to three calls per turn', () async {
    late FakeAiAssistantRepository assistant;
    assistant = FakeAiAssistantRepository(
      responseStreamBuilder: (_) {
        if (assistant.startedRequests.length == 1) {
          return Stream.fromIterable([
            for (var index = 1; index <= 4; index++)
              AiToolCallRequested(
                id: 'search-$index',
                name: AiWebSearchToolNames.searchWeb,
                arguments: {
                  'query': 'query $index',
                  'resultLimit': 1,
                  'freshness': 'any',
                },
              ),
            const AiResponseCompleted(finishReason: 'tool_calls'),
          ]);
        }
        return Stream.fromIterable(const [AiResponseCompleted()]);
      },
    );
    final search = _FakeSearchRepository(const []);
    final coordinator = AiApplicationToolCoordinator(
      assistantRepository: assistant,
      webSearchRepository: search,
    );

    final handle = await coordinator.startResponse(
      _request(modelProfile, searchProfile),
    );
    await handle.events.toList();

    expect(search.requests, hasLength(3));
    final results =
        assistant.startedRequests.last.continuationMessages
            .whereType<AiToolResultMessage>()
            .toList();
    expect(results, hasLength(4));
    expect(results.last.isError, isTrue);
    expect(results.last.result['code'], 'tool_call_limit');
  });

  test('cancels an in-flight web search with the response', () async {
    final started = Completer<void>();
    final search = _BlockingSearchRepository(started);
    final assistant = FakeAiAssistantRepository(
      responseEvents: [
        AiToolCallRequested(
          id: 'search',
          name: AiWebSearchToolNames.searchWeb,
          arguments: const {
            'query': 'wait',
            'resultLimit': 1,
            'freshness': 'any',
          },
        ),
        const AiResponseCompleted(finishReason: 'tool_calls'),
      ],
    );
    final coordinator = AiApplicationToolCoordinator(
      assistantRepository: assistant,
      webSearchRepository: search,
      executionTimeout: const Duration(minutes: 1),
    );
    final handle = await coordinator.startResponse(
      _request(modelProfile, searchProfile),
    );
    final events = handle.events.toList();

    await started.future;
    await handle.cancel();

    expect(await events, isEmpty);
    expect(search.cancelled, isTrue);
  });
}

AiChatRequest _request(
  AiConnectionProfile modelProfile,
  AiWebSearchConnectionProfile searchProfile, {
  bool authorize = true,
}) => AiChatRequest(
  connectionProfile: modelProfile,
  conversationId: 'conversation',
  messages: [
    AiChatMessage(
      id: 'message',
      role: AiMessageRole.user,
      content: 'Find current information.',
      createdAt: DateTime.utc(2026, 9, 7),
    ),
  ],
  webSearchProfile: searchProfile,
  webSearchAuthorization:
      authorize
          ? AiWebSearchAuthorization(connectionProfileId: searchProfile.id)
          : null,
  webSearchExecutorAvailable: true,
);

class _FakeSearchRepository implements AiWebSearchRepository {
  _FakeSearchRepository(this.results);

  final List<AiWebSearchResult> results;
  final List<AiWebSearchRequest> requests = [];

  @override
  bool get isAvailable => true;

  @override
  Future<AiWebSearchResponseHandle> startSearch(
    AiWebSearchConnectionProfile profile,
    AiWebSearchRequest request,
  ) async {
    requests.add(request);
    return FutureAiWebSearchResponseHandle(
      results: Future.value(results),
      onCancel: () async {},
    );
  }

  @override
  Future<AiConnectionResult> testConnection(
    AiWebSearchConnectionProfile profile,
  ) async => const AiConnectionResult.connected();
}

final class _BlockingSearchRepository extends _FakeSearchRepository {
  _BlockingSearchRepository(this.started) : super(const []);

  final Completer<void> started;
  final Completer<List<AiWebSearchResult>> _result = Completer();
  bool cancelled = false;

  @override
  Future<AiWebSearchResponseHandle> startSearch(
    AiWebSearchConnectionProfile profile,
    AiWebSearchRequest request,
  ) async {
    requests.add(request);
    started.complete();
    return FutureAiWebSearchResponseHandle(
      results: _result.future,
      onCancel: () async {
        cancelled = true;
        if (!_result.isCompleted) _result.complete(const []);
      },
    );
  }
}
