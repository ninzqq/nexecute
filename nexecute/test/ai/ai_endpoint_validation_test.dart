import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  test('accepts a complete HTTPS base URL', () {
    final result = validateAiEndpointUrl(
      'https://ai.example.test/v1',
      isWeb: true,
    );

    expect(result.isValid, isTrue);
    expect(result.uri, Uri.parse('https://ai.example.test/v1'));
    expect(result.warning, isNull);
  });

  test('warns that web clients may block a plain HTTP endpoint', () {
    final result = validateAiEndpointUrl(
      'http://ai-pc.example.test:11434/v1',
      isWeb: true,
    );

    expect(result.isValid, isTrue);
    expect(result.warning, contains('blocked'));
    expect(result.warning, contains('HTTPS'));
  });

  test('warns native clients to limit plain HTTP to trusted networks', () {
    final result = validateAiEndpointUrl(
      'http://ai-pc.example.test:11434/v1',
      isWeb: false,
    );

    expect(result.isValid, isTrue);
    expect(result.warning, contains('trusted local network or tailnet'));
  });

  test('warns when localhost would refer to the client device', () {
    final result = validateAiEndpointUrl(
      'http://localhost:11434/v1',
      isWeb: false,
    );

    expect(result.isValid, isTrue);
    expect(result.warning, contains('localhost points to this device'));
  });

  test('rejects missing schemes, credentials, queries, and fragments', () {
    expect(
      validateAiEndpointUrl('ai.example.test/v1', isWeb: false).error,
      isNotNull,
    );
    expect(
      validateAiEndpointUrl(
        'https://user:secret@ai.example.test/v1',
        isWeb: false,
      ).error,
      contains('credentials'),
    );
    expect(
      validateAiEndpointUrl(
        'https://ai.example.test/v1?key=value',
        isWeb: false,
      ).error,
      contains('query'),
    );
    expect(
      validateAiEndpointUrl(
        'https://ai.example.test/v1#fragment',
        isWeb: false,
      ).error,
      contains('fragment'),
    );
  });
}
