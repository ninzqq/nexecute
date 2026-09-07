import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nexecute/ai/domain/ai_connection_result.dart';
import 'package:nexecute/ai/domain/ai_diagnostic.dart';
import 'package:nexecute/ai/domain/ai_web_search.dart';
import 'package:nexecute/ai/infrastructure/ai_failure_diagnostics.dart';
import 'package:nexecute/ai/infrastructure/ai_web_search_result_sanitizer.dart';
import 'package:nexecute/ai/repositories/ai_credential_store.dart';
import 'package:nexecute/ai/repositories/ai_web_search_repository.dart';

const aiBraveSearchMaxResponseBytes = 1024 * 1024;

final class BraveAiWebSearchRepository implements AiWebSearchRepository {
  BraveAiWebSearchRepository({
    required AiCredentialStore credentialStore,
    http.Client? client,
    AiFailureDiagnostics? failureDiagnostics,
    bool isWeb = kIsWeb,
  }) : _credentialStore = credentialStore,
       _client = client ?? http.Client(),
       _ownsClient = client == null,
       _isWeb = isWeb,
       _failureDiagnostics = failureDiagnostics ?? AiFailureDiagnostics();

  final AiCredentialStore _credentialStore;
  final http.Client _client;
  final bool _ownsClient;
  final bool _isWeb;
  final AiFailureDiagnostics _failureDiagnostics;

  @override
  bool get isAvailable => !_isWeb;

  @override
  Future<AiConnectionResult> testConnection(
    AiWebSearchConnectionProfile profile,
  ) async {
    final stopwatch = Stopwatch()..start();
    AiWebSearchResponseHandle? handle;
    try {
      handle = await startSearch(
        profile,
        AiWebSearchRequest(query: 'Nexecute connection test', resultLimit: 1),
      );
      await handle.results;
      stopwatch.stop();
      return AiConnectionResult.connected(
        message: 'Connected to Brave Search.',
        latency: stopwatch.elapsed,
      );
    } on AiDiagnosticException catch (error) {
      return AiConnectionResult(
        status: _connectionStatus(error.diagnostic.kind),
        message: error.message,
        diagnostic: error.diagnostic,
      );
    } catch (_) {
      return AiConnectionResult(
        status: AiConnectionStatus.failed,
        message: 'The Brave Search connection test failed.',
        diagnostic: _searchDiagnostic(AiDiagnosticKind.unknown),
      );
    } finally {
      await handle?.cancel();
    }
  }

  @override
  Future<AiWebSearchResponseHandle> startSearch(
    AiWebSearchConnectionProfile profile,
    AiWebSearchRequest request,
  ) async {
    if (_isWeb ||
        !profile.enabled ||
        !profile.isValid ||
        profile.providerKind != AiWebSearchProviderKind.brave) {
      throw AiDiagnosticException(
        diagnostic: _searchDiagnostic(AiDiagnosticKind.invalidConfiguration),
        message: 'The Brave Search connection is incomplete or disabled.',
      );
    }
    final reference = profile.credentialReference!;
    final String? credential;
    try {
      credential = await _credentialStore.readCredential(reference);
    } on AiCredentialStoreException catch (error) {
      throw AiDiagnosticException(
        diagnostic: _searchDiagnostic(AiDiagnosticKind.invalidConfiguration),
        message: 'The Brave Search API key is unavailable on this device.',
        cause: error,
      );
    }
    if (credential == null || credential.trim().isEmpty) {
      throw AiDiagnosticException(
        diagnostic: _searchDiagnostic(AiDiagnosticKind.invalidConfiguration),
        message: 'The Brave Search API key is unavailable on this device.',
      );
    }

    final abort = Completer<void>();
    return FutureAiWebSearchResponseHandle(
      results: _search(profile, request, credential.trim(), abort),
      onCancel: () async {
        if (!abort.isCompleted) abort.complete();
      },
    );
  }

  Future<List<AiWebSearchResult>> _search(
    AiWebSearchConnectionProfile profile,
    AiWebSearchRequest request,
    String credential,
    Completer<void> abort,
  ) async {
    final endpoint = profile.baseUrl.replace(
      queryParameters: {
        'q': request.query,
        'count': request.resultLimit.toString(),
        'country': profile.country.toUpperCase(),
        'search_lang': profile.searchLanguage,
        'safesearch': profile.safeSearch.name,
        'result_filter': 'web',
        'text_decorations': 'false',
        if (request.freshness != AiWebSearchFreshness.any)
          'freshness': _freshness(request.freshness),
      },
    );
    final httpRequest = http.AbortableRequest(
      'GET',
      endpoint,
      abortTrigger: abort.future,
    );
    httpRequest.headers.addAll({
      'accept': 'application/json',
      'x-subscription-token': credential,
    });
    try {
      final stopwatch = Stopwatch()..start();
      final response = await _client
          .send(httpRequest)
          .timeout(profile.requestTimeout);
      final remaining = profile.requestTimeout - stopwatch.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException('Search timed out');
      }
      final body = await _boundedBody(response, abort).timeout(remaining);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiDiagnosticException(
          diagnostic: _httpDiagnostic(response.statusCode),
          message: _httpMessage(response.statusCode),
          cause: BraveSearchHttpException(response.statusCode),
        );
      }
      return _decodeResults(body, request.resultLimit);
    } on AiDiagnosticException {
      rethrow;
    } on TimeoutException catch (error) {
      if (!abort.isCompleted) abort.complete();
      throw AiDiagnosticException(
        diagnostic: _searchDiagnostic(AiDiagnosticKind.timeout),
        message: 'Brave Search did not respond in time.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw AiDiagnosticException(
        diagnostic: _searchDiagnostic(AiDiagnosticKind.invalidResponse),
        message: 'Brave Search returned an invalid response.',
        cause: error,
      );
    } on http.RequestAbortedException catch (error) {
      throw AiWebSearchCancelledException(error);
    } on http.ClientException catch (error) {
      if (abort.isCompleted) throw AiWebSearchCancelledException(error);
      throw AiDiagnosticException(
        diagnostic: _failureDiagnostics.transportFailure(
          error,
          endpoint: profile.baseUrl,
        ),
        message: 'Could not reach Brave Search.',
        cause: error,
      );
    } catch (error) {
      final recognized = _failureDiagnostics.recognizedNativeTransportFailure(
        error,
        endpoint: profile.baseUrl,
      );
      throw AiDiagnosticException(
        diagnostic: recognized ?? _searchDiagnostic(AiDiagnosticKind.unknown),
        message:
            recognized == null
                ? 'The Brave Search request failed.'
                : 'Could not establish a secure connection to Brave Search.',
        cause: error,
      );
    }
  }

  Future<String> _boundedBody(
    http.StreamedResponse response,
    Completer<void> abort,
  ) async {
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > aiBraveSearchMaxResponseBytes) {
        if (!abort.isCompleted) abort.complete();
        throw const FormatException('Search response exceeds the size limit.');
      }
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes, allowMalformed: false);
  }

  List<AiWebSearchResult> _decodeResults(String source, int limit) {
    final decoded = jsonDecode(source);
    if (decoded is! Map || decoded['web'] is! Map) {
      throw const FormatException('Missing web search results.');
    }
    final web = decoded['web'] as Map;
    if (web['results'] is! List) {
      throw const FormatException('Missing web search result list.');
    }
    final results = <AiWebSearchResult>[];
    final seen = <String>{};
    for (final value in web['results'] as List) {
      if (results.length >= limit) break;
      if (value is! Map) continue;
      final result = AiWebSearchResultSanitizer.normalize(
        sourceId: 'result-${results.length + 1}',
        title: value['title'],
        url: value['url'],
        snippet: value['description'],
        publishedAt: value['page_age'],
        providerName: AiWebSearchProviderCatalog.brave.label,
      );
      if (result != null && seen.add(result.url.toString())) {
        results.add(result);
      }
    }
    return List.unmodifiable(results);
  }

  AiDiagnostic _httpDiagnostic(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return _searchDiagnostic(AiDiagnosticKind.authentication);
    }
    if (statusCode == 408) {
      return _searchDiagnostic(AiDiagnosticKind.timeout);
    }
    if (statusCode == 429) {
      return _searchDiagnostic(AiDiagnosticKind.rateLimited);
    }
    if (statusCode >= 500) {
      return _searchDiagnostic(AiDiagnosticKind.serverUnavailable);
    }
    if (statusCode == 400 || statusCode == 404 || statusCode == 422) {
      return _searchDiagnostic(AiDiagnosticKind.protocolIncompatible);
    }
    return _searchDiagnostic(AiDiagnosticKind.unknown);
  }

  static String _httpMessage(int statusCode) => switch (statusCode) {
    401 || 403 => 'Brave Search rejected the configured API key.',
    408 => 'Brave Search did not respond in time.',
    429 =>
      'Brave Search is rate limiting requests or the plan limit was reached.',
    >= 500 => 'Brave Search is temporarily unavailable.',
    _ => 'Brave Search rejected the request.',
  };

  static String _freshness(AiWebSearchFreshness value) => switch (value) {
    AiWebSearchFreshness.any => '',
    AiWebSearchFreshness.day => 'pd',
    AiWebSearchFreshness.week => 'pw',
    AiWebSearchFreshness.month => 'pm',
    AiWebSearchFreshness.year => 'py',
  };

  static AiConnectionStatus _connectionStatus(
    AiDiagnosticKind kind,
  ) => switch (kind) {
    AiDiagnosticKind.invalidConfiguration =>
      AiConnectionStatus.invalidConfiguration,
    AiDiagnosticKind.authentication => AiConnectionStatus.authenticationFailed,
    AiDiagnosticKind.timeout => AiConnectionStatus.timeout,
    AiDiagnosticKind.unreachable ||
    AiDiagnosticKind.dns ||
    AiDiagnosticKind.tls => AiConnectionStatus.unreachable,
    AiDiagnosticKind.unsupported => AiConnectionStatus.unsupported,
    _ => AiConnectionStatus.failed,
  };

  static AiDiagnostic _searchDiagnostic(
    AiDiagnosticKind kind,
  ) => switch (kind) {
    AiDiagnosticKind.invalidConfiguration => AiDiagnostic(
      kind: kind,
      title: 'Search connection is incomplete',
      summary: 'The Brave Search connection cannot be used as configured.',
      suggestions: const ['Review the search connection in AI Settings.'],
    ),
    AiDiagnosticKind.authentication => AiDiagnostic(
      kind: kind,
      title: 'Search authentication failed',
      summary: 'Brave Search rejected the configured API key.',
      suggestions: const ['Replace the Brave Search API key in AI Settings.'],
    ),
    AiDiagnosticKind.timeout => AiDiagnostic(
      kind: kind,
      title: 'Search timed out',
      summary: 'Brave Search did not respond before the configured timeout.',
      suggestions: const ['Check the network connection and try again.'],
    ),
    AiDiagnosticKind.rateLimited => AiDiagnostic(
      kind: kind,
      title: 'Search limit reached',
      summary: 'Brave Search temporarily refused another request.',
      suggestions: const [
        'Wait before trying again and review the Brave Search plan usage.',
      ],
    ),
    AiDiagnosticKind.serverUnavailable => AiDiagnostic(
      kind: kind,
      title: 'Search service unavailable',
      summary: 'Brave Search reported a server-side failure.',
      suggestions: const ['Try the search again later.'],
    ),
    AiDiagnosticKind.protocolIncompatible => AiDiagnostic(
      kind: kind,
      title: 'Search request rejected',
      summary: 'Brave Search rejected the request format.',
      suggestions: const ['Update Nexecute before trying again.'],
    ),
    AiDiagnosticKind.invalidResponse => AiDiagnostic(
      kind: kind,
      title: 'Invalid search response',
      summary: 'Brave Search returned data Nexecute could not safely use.',
      suggestions: const ['Try the search again.'],
    ),
    _ => AiDiagnostic(
      kind: kind,
      title: 'Web search failed',
      summary: 'The web-search operation could not be completed.',
      suggestions: const ['Check the connection and try again.'],
    ),
  };

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

final class BraveSearchHttpException implements Exception {
  const BraveSearchHttpException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'Brave Search HTTP $statusCode';
}
