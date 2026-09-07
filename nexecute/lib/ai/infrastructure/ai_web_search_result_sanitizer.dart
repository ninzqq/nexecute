import 'package:nexecute/ai/domain/ai_web_search.dart';

const aiWebSearchMaxTitleCharacters = 300;
const aiWebSearchMaxSnippetCharacters = 2000;

abstract final class AiWebSearchResultSanitizer {
  static AiWebSearchResult? normalize({
    required String sourceId,
    required Object? title,
    required Object? url,
    required Object? snippet,
    required String providerName,
    Object? publishedAt,
  }) {
    final normalizedUrl = canonicalPublicHttpsUrl(url);
    if (normalizedUrl == null) return null;
    final normalizedTitle = _plainText(
      title,
      maximumCharacters: aiWebSearchMaxTitleCharacters,
    );
    if (normalizedTitle.isEmpty) return null;
    return AiWebSearchResult(
      sourceId: sourceId,
      title: normalizedTitle,
      url: normalizedUrl,
      snippet: _plainText(
        snippet,
        maximumCharacters: aiWebSearchMaxSnippetCharacters,
      ),
      providerName: providerName,
      publishedAt:
          publishedAt is String
              ? DateTime.tryParse(publishedAt)?.toUtc()
              : null,
    );
  }

  static Uri? canonicalPublicHttpsUrl(Object? value) {
    if (value is! String || value.length > aiWebSearchMaxEndpointCharacters) {
      return null;
    }
    final parsed = Uri.tryParse(value.trim());
    if (parsed == null ||
        parsed.scheme.toLowerCase() != 'https' ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty ||
        !_isPublicHost(parsed.host) ||
        _isUnresolvedProviderRedirect(parsed)) {
      return null;
    }
    final retained = <MapEntry<String, String>>[];
    for (final entry in parsed.queryParametersAll.entries) {
      if (_isTrackingParameter(entry.key)) continue;
      for (final value in entry.value) {
        retained.add(MapEntry(entry.key, value));
      }
    }
    retained.sort((left, right) {
      final byKey = left.key.compareTo(right.key);
      return byKey != 0 ? byKey : left.value.compareTo(right.value);
    });
    final query = retained
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}='
              '${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
    return Uri(
      scheme: 'https',
      host: parsed.host.toLowerCase(),
      port: parsed.hasPort ? parsed.port : null,
      path: parsed.path.isEmpty ? '/' : parsed.path,
      query: query.isEmpty ? null : query,
    );
  }
}

String _plainText(Object? value, {required int maximumCharacters}) {
  if (value is! String) return '';
  var text = value;
  text = text.replaceAllMapped(RegExp(r'&#(x?[0-9a-fA-F]+);'), (match) {
    final source = match.group(1)!;
    final radix = source.startsWith('x') ? 16 : 10;
    final digits = source.startsWith('x') ? source.substring(1) : source;
    final value = int.tryParse(digits, radix: radix);
    return value == null || value == 0 || value > 0x10ffff
        ? ' '
        : String.fromCharCode(value);
  });
  const entities = {
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&nbsp;': ' ',
  };
  for (final entry in entities.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  text =
      text
          .replaceAll(RegExp(r'<[^>]*>', multiLine: true), ' ')
          .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
  if (text.runes.length <= maximumCharacters) return text;
  return String.fromCharCodes(text.runes.take(maximumCharacters)).trimRight();
}

bool _isTrackingParameter(String name) {
  final normalized = name.toLowerCase();
  return normalized.startsWith('utm_') ||
      const {
        'fbclid',
        'gclid',
        'dclid',
        'msclkid',
        'mc_cid',
        'mc_eid',
      }.contains(normalized);
}

bool _isUnresolvedProviderRedirect(Uri uri) {
  final host = uri.host.toLowerCase();
  return (host == 'search.brave.com' || host == 'brave.com') &&
      (uri.path.toLowerCase().contains('redirect') ||
          uri.queryParameters.keys.any(
            (key) =>
                const {'url', 'target', 'redirect'}.contains(key.toLowerCase()),
          ));
}

bool _isPublicHost(String host) {
  final normalized = host.toLowerCase();
  if (normalized == 'localhost' ||
      normalized.endsWith('.localhost') ||
      normalized.endsWith('.local') ||
      normalized.endsWith('.internal')) {
    return false;
  }
  final ipv4 = _parseIpv4(normalized);
  if (ipv4 != null) return !_isPrivateIpv4(ipv4);
  if (RegExp(r'^[0-9.]+$').hasMatch(normalized)) return false;
  if (normalized.contains(':')) return !_isPrivateIpv6(normalized);
  return RegExp(
    r'^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$',
  ).hasMatch(normalized);
}

List<int>? _parseIpv4(String host) {
  final parts = host.split('.');
  if (parts.length != 4) return null;
  final octets = parts.map(int.tryParse).toList();
  if (octets.any((value) => value == null || value < 0 || value > 255)) {
    return null;
  }
  return octets.cast<int>();
}

bool _isPrivateIpv4(List<int> octets) {
  final first = octets[0];
  final second = octets[1];
  return first == 0 ||
      first == 10 ||
      first == 127 ||
      (first == 100 && second >= 64 && second <= 127) ||
      (first == 169 && second == 254) ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 192 && second == 0) ||
      (first == 192 && second == 168) ||
      (first == 198 && (second == 18 || second == 19)) ||
      first >= 224;
}

bool _isPrivateIpv6(String host) {
  final normalized = host.toLowerCase();
  return normalized == '::' ||
      normalized == '::1' ||
      normalized.startsWith('fc') ||
      normalized.startsWith('fd') ||
      normalized.startsWith('fe8') ||
      normalized.startsWith('fe9') ||
      normalized.startsWith('fea') ||
      normalized.startsWith('feb') ||
      normalized.startsWith('ff') ||
      normalized.startsWith('::ffff:') ||
      normalized.startsWith('2001:db8:');
}
