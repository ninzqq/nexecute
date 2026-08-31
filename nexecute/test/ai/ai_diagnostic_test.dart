import 'package:nexecute/ai/ai.dart';
import 'package:test/test.dart';

void main() {
  test('exposes stable codes for every provider-neutral diagnostic kind', () {
    expect(
      AiDiagnosticKind.values.map((kind) => kind.code),
      containsAll(<String>{
        'invalid_configuration',
        'dns',
        'tls',
        'browser_mixed_content',
        'browser_cors_or_network',
        'local_network',
        'authentication',
        'endpoint_not_found',
        'model_not_found',
        'timeout',
        'rate_limited',
        'server_unavailable',
        'protocol_incompatible',
        'invalid_response',
        'unreachable',
        'unsupported',
        'unknown',
      }),
    );
    expect(
      AiDiagnosticKind.values.map((kind) => kind.code).toSet(),
      hasLength(AiDiagnosticKind.values.length),
    );
    expect(AiDiagnosticKind.fromCode('dns'), AiDiagnosticKind.dns);
    expect(AiDiagnosticKind.fromCode('future_category'), isNull);
  });

  test('normalizes and protects user-facing diagnostic guidance', () {
    final sourceSuggestions = [' Check the endpoint address. '];
    final diagnostic = AiDiagnostic(
      kind: AiDiagnosticKind.dns,
      title: ' Host not found ',
      summary: ' The endpoint name could not be resolved. ',
      suggestions: sourceSuggestions,
    );
    sourceSuggestions.add('Changed after creation');

    expect(diagnostic.code, 'dns');
    expect(diagnostic.title, 'Host not found');
    expect(diagnostic.summary, 'The endpoint name could not be resolved.');
    expect(diagnostic.suggestions, ['Check the endpoint address.']);
    expect(
      () => diagnostic.suggestions.add('Another check'),
      throwsUnsupportedError,
    );
  });

  test('rejects empty diagnostic text', () {
    expect(
      () => AiDiagnostic(
        kind: AiDiagnosticKind.unknown,
        title: ' ',
        summary: 'Something failed.',
      ),
      throwsArgumentError,
    );
    expect(
      () => AiDiagnostic(
        kind: AiDiagnosticKind.unknown,
        title: 'Request failed',
        summary: 'Something failed.',
        suggestions: const [''],
      ),
      throwsArgumentError,
    );
    final diagnostic = AiDiagnostic(
      kind: AiDiagnosticKind.unknown,
      title: 'Request failed',
      summary: 'Something failed.',
    );
    expect(
      () => AiDiagnosticException(diagnostic: diagnostic, message: ' '),
      throwsArgumentError,
    );
  });

  test('can accompany connection and streamed-response failures', () {
    final diagnostic = AiDiagnostic(
      kind: AiDiagnosticKind.authentication,
      title: 'Authentication failed',
      summary: 'The endpoint rejected the configured credential.',
      suggestions: const ['Check the credential in AI Settings.'],
    );
    final connectionResult = AiConnectionResult(
      status: AiConnectionStatus.authenticationFailed,
      message: diagnostic.summary,
      diagnostic: diagnostic,
    );
    final responseFailure = AiResponseFailed(
      error: StateError('rejected'),
      message: diagnostic.summary,
      code: 'http_401',
      diagnostic: diagnostic,
    );

    expect(connectionResult.diagnostic, same(diagnostic));
    expect(responseFailure.diagnostic, same(diagnostic));
    expect(const AiConnectionResult.connected().diagnostic, isNull);
  });
}
