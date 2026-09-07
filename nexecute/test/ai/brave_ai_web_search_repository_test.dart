import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexecute/ai/ai.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  const credentialReference = 'secure-storage:brave';
  const apiKey = 'secret-brave-key';

  AiWebSearchConnectionProfile profile({
    Duration timeout = const Duration(seconds: 1),
  }) => AiWebSearchConnectionProfile(
    id: 'brave',
    name: 'Brave',
    providerKind: AiWebSearchProviderKind.brave,
    baseUrl: AiWebSearchProviderCatalog.brave.trustedBaseUri!,
    enabled: true,
    credentialReference: credentialReference,
    country: 'FI',
    searchLanguage: 'fi',
    safeSearch: AiWebSearchSafeSearch.strict,
    requestTimeout: timeout,
  );

  test('uses the fixed Brave request and normalizes public results', () async {
    late http.Request sent;
    final repository = BraveAiWebSearchRepository(
      isWeb: false,
      credentialStore: FakeAiCredentialStore(
        credentials: const {credentialReference: apiKey},
      ),
      client: MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'web': {
              'results': [
                {
                  'title': '<b>Example &amp; result</b>',
                  'url': 'https://Example.com?a=2&utm_source=tracking#section',
                  'description': 'A <script>bad()</script> useful result',
                  'page_age': '2026-09-06T10:00:00Z',
                },
                {
                  'title': 'Private',
                  'url': 'https://127.0.0.1/private',
                  'description': 'Rejected',
                },
              ],
            },
          }),
          200,
        );
      }),
    );

    final handle = await repository.startSearch(
      profile(),
      AiWebSearchRequest(
        query: 'latest Flutter release',
        resultLimit: 3,
        freshness: AiWebSearchFreshness.week,
      ),
    );
    final results = await handle.results;

    expect(sent.url.origin + sent.url.path, profile().baseUrl.toString());
    expect(
      sent.url.queryParameters,
      containsPair('q', 'latest Flutter release'),
    );
    expect(sent.url.queryParameters, containsPair('count', '3'));
    expect(sent.url.queryParameters, containsPair('country', 'FI'));
    expect(sent.url.queryParameters, containsPair('search_lang', 'fi'));
    expect(sent.url.queryParameters, containsPair('safesearch', 'strict'));
    expect(sent.url.queryParameters, containsPair('freshness', 'pw'));
    expect(sent.headers['x-subscription-token'], apiKey);
    expect(results, hasLength(1));
    expect(results.single.title, 'Example & result');
    expect(results.single.snippet, 'A bad() useful result');
    expect(results.single.url.toString(), 'https://example.com/?a=2');
  });

  test(
    'redacts provider response and credentials from authentication errors',
    () async {
      final repository = BraveAiWebSearchRepository(
        isWeb: false,
        credentialStore: FakeAiCredentialStore(
          credentials: const {credentialReference: apiKey},
        ),
        client: MockClient(
          (_) async => http.Response('raw payload with $apiKey', 401),
        ),
      );
      final handle = await repository.startSearch(
        profile(),
        AiWebSearchRequest(query: 'private query words'),
      );

      final error = await handle.results.then<Object?>(
        (_) => null,
        onError: (e) => e,
      );

      expect(error, isA<AiDiagnosticException>());
      final text = error.toString();
      expect(text, isNot(contains(apiKey)));
      expect(text, isNot(contains('raw payload')));
      expect(text, isNot(contains('private query')));
      expect(
        (error as AiDiagnosticException).diagnostic.kind,
        AiDiagnosticKind.authentication,
      );
    },
  );

  test('maps Brave rate limiting to a safe diagnostic', () async {
    final repository = BraveAiWebSearchRepository(
      isWeb: false,
      credentialStore: FakeAiCredentialStore(
        credentials: const {credentialReference: apiKey},
      ),
      client: MockClient((_) async => http.Response('plan details', 429)),
    );
    final handle = await repository.startSearch(
      profile(),
      AiWebSearchRequest(query: 'limited query'),
    );

    final error =
        await handle.results.then<Object?>((_) => null, onError: (e) => e)
            as AiDiagnosticException;

    expect(error.diagnostic.kind, AiDiagnosticKind.rateLimited);
    expect(error.message, isNot(contains('plan details')));
    expect(error.message, isNot(contains('limited query')));
  });

  test('cancels an in-flight request', () async {
    final started = Completer<void>();
    final repository = BraveAiWebSearchRepository(
      isWeb: false,
      credentialStore: FakeAiCredentialStore(
        credentials: const {credentialReference: apiKey},
      ),
      client: _AbortClient((request) async {
        started.complete();
        await (request as http.AbortableRequest).abortTrigger;
        throw http.RequestAbortedException(request.url);
      }),
    );
    final handle = await repository.startSearch(
      profile(timeout: const Duration(minutes: 1)),
      AiWebSearchRequest(query: 'cancel this'),
    );
    final result = handle.results.then<Object?>(
      (value) => value,
      onError: (e) => e,
    );

    await started.future;
    await handle.cancel();

    expect(await result, isA<AiWebSearchCancelledException>());
  });

  test('is unavailable and rejects credentials in a web build', () async {
    final repository = BraveAiWebSearchRepository(
      isWeb: true,
      credentialStore: FakeAiCredentialStore(
        credentials: const {credentialReference: apiKey},
      ),
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    expect(repository.isAvailable, isFalse);
    expect(
      () => repository.startSearch(
        profile(),
        AiWebSearchRequest(query: 'blocked'),
      ),
      throwsA(isA<AiDiagnosticException>()),
    );
  });
}

final class _AbortClient extends http.BaseClient {
  _AbortClient(this.sendCallback);

  final Future<http.StreamedResponse> Function(http.BaseRequest) sendCallback;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      sendCallback(request);
}
