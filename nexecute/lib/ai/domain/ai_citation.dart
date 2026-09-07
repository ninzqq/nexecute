const aiMaxCitationsPerMessage = 15;
const aiMaxCitationTitleCharacters = 300;

final class AiCitation {
  AiCitation({
    required this.sourceId,
    required String title,
    required this.url,
    this.publishedAt,
  }) : title = title.trim() {
    if (!RegExp(r'^web-[1-9][0-9]*$').hasMatch(sourceId)) {
      throw ArgumentError.value(sourceId, 'sourceId', 'is not a web source ID');
    }
    if (this.title.isEmpty ||
        this.title.runes.length > aiMaxCitationTitleCharacters) {
      throw ArgumentError.value(title, 'title', 'has an unsupported length');
    }
    if (url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasFragment) {
      throw ArgumentError.value(url, 'url', 'must be a canonical HTTPS URL');
    }
  }

  final String sourceId;
  final String title;
  final Uri url;
  final DateTime? publishedAt;
}
