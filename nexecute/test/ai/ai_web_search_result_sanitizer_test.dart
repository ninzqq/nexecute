import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  test('accepts and canonicalizes public HTTPS URLs', () {
    final result = AiWebSearchResultSanitizer.canonicalPublicHttpsUrl(
      'https://Example.COM?z=2&utm_medium=x&a=1#fragment',
    );

    expect(result.toString(), 'https://example.com/?a=1&z=2');
  });

  test('rejects unsafe and non-public targets', () {
    for (final value in [
      'http://example.com',
      'https://user:pass@example.com/',
      'https://localhost/',
      'https://10.0.0.1/',
      'https://[::1]/',
      'https://999.999.999.999/',
      'https://search.brave.com/redirect?url=https://example.com',
    ]) {
      expect(
        AiWebSearchResultSanitizer.canonicalPublicHttpsUrl(value),
        isNull,
        reason: value,
      );
    }
  });

  test('decodes text and removes markup and control characters', () {
    final result = AiWebSearchResultSanitizer.normalize(
      sourceId: 'one',
      title: '&lt;b&gt;Hello&lt;/b&gt;\u0000 &amp; welcome',
      url: 'https://example.com',
      snippet: '<div>Visible</div>\ntext',
      providerName: 'Brave',
    );

    expect(result?.title, 'Hello & welcome');
    expect(result?.snippet, 'Visible text');
  });
}
