import 'package:nexecute/ai/domain/ai_citation.dart';

final class AiCitationResolution {
  AiCitationResolution({
    required this.content,
    required List<AiCitation> citations,
  }) : citations = List.unmodifiable(citations);

  final String content;
  final List<AiCitation> citations;
}

abstract final class AiCitationResolver {
  static final RegExp _marker = RegExp(r'\[\[(web-[^\]\r\n]*)\]\]');

  static AiCitationResolution resolve(
    String content,
    Iterable<AiCitation> available,
  ) {
    final byId = {
      for (final citation in available) citation.sourceId: citation,
    };
    final cited = <AiCitation>[];
    final numbers = <String, int>{};
    final normalized = content.replaceAllMapped(_marker, (match) {
      final sourceId = match.group(1)!;
      final citation = byId[sourceId];
      if (citation == null) return '';
      final number = numbers.putIfAbsent(sourceId, () {
        if (cited.length >= aiMaxCitationsPerMessage) return 0;
        cited.add(citation);
        return cited.length;
      });
      return number == 0 ? '' : '[$number]';
    });
    return AiCitationResolution(
      content: normalized.replaceAll(RegExp(r' {2,}'), ' ').trimRight(),
      citations: cited,
    );
  }

  static String copyText({
    required String content,
    required List<AiCitation> citations,
  }) {
    if (citations.isEmpty) return content;
    final buffer =
        StringBuffer(content.trimRight())
          ..writeln()
          ..writeln()
          ..writeln('Sources:');
    for (var index = 0; index < citations.length; index++) {
      final citation = citations[index];
      buffer.writeln('[${index + 1}] ${citation.title} — ${citation.url}');
    }
    return buffer.toString().trimRight();
  }
}
