import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  final first = AiCitation(
    sourceId: 'web-1',
    title: 'Current release',
    url: Uri.parse('https://example.com/release'),
    publishedAt: DateTime.utc(2026, 9, 1),
  );
  final second = AiCitation(
    sourceId: 'web-2',
    title: 'Conflicting report',
    url: Uri.parse('https://news.example.org/report'),
  );

  test('resolves valid markers by first use and drops fabricated IDs', () {
    final result = AiCitationResolver.resolve(
      'Claim B [[web-2]]. Claim A [[web-1]] and again [[web-2]]. '
      'Unsupported [[web-999]] and malformed [[web-x]].',
      [first, second],
    );

    expect(
      result.content,
      'Claim B [1]. Claim A [2] and again [1]. Unsupported and malformed .',
    );
    expect(result.citations.map((value) => value.sourceId), ['web-2', 'web-1']);
    expect(result.citations.last.publishedAt, DateTime.utc(2026, 9, 1));
  });

  test('returns no citations for unsupported claims or missing results', () {
    final unsupported = AiCitationResolver.resolve(
      'A claim without evidence.',
      [first],
    );
    final missing = AiCitationResolver.resolve(
      'Väitteen lähde [[web-1]].',
      const [],
    );

    expect(unsupported.citations, isEmpty);
    expect(missing.citations, isEmpty);
    expect(missing.content, 'Väitteen lähde .');
  });

  test('copy output includes exact links and preserves bilingual text', () {
    final copied = AiCitationResolver.copyText(
      content: 'Sources disagree [1][2]. Lähteet ovat eri mieltä.',
      citations: [first, second],
    );

    expect(
      copied,
      contains('[1] Current release — https://example.com/release'),
    );
    expect(
      copied,
      contains('[2] Conflicting report — https://news.example.org/report'),
    );
    expect(copied, contains('Lähteet ovat eri mieltä.'));
  });
}
