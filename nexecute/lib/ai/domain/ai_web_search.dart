const aiWebSearchMaxQueryCharacters = 400;
const aiWebSearchMaxQueryWords = 50;
const aiWebSearchMaxResults = 5;
const aiWebSearchMaxCallsPerTurn = 3;
const aiWebSearchMaxContextCharacters = 12000;
const aiWebSearchDefaultTimeout = Duration(seconds: 15);
const aiWebSearchMaxTimeout = Duration(seconds: 60);
const aiWebSearchMaxProfileIdCharacters = 128;
const aiWebSearchMaxProfileNameCharacters = 100;
const aiWebSearchMaxEndpointCharacters = 2048;
const aiWebSearchMaxCredentialReferenceCharacters = 256;

enum AiWebSearchProviderKind { brave, searxng }

enum AiWebSearchSafeSearch { off, moderate, strict }

enum AiWebSearchFreshness { any, day, week, month, year }

final class AiWebSearchProviderDescriptor {
  const AiWebSearchProviderDescriptor({
    required this.kind,
    required this.label,
    required this.requiresCredential,
    required this.hosted,
    this.trustedBaseUrl,
    this.documentationUrl,
    this.keyManagementUrl,
    this.billingUrl,
  });

  final AiWebSearchProviderKind kind;
  final String label;
  final bool requiresCredential;
  final bool hosted;
  final String? trustedBaseUrl;
  final String? documentationUrl;
  final String? keyManagementUrl;
  final String? billingUrl;

  Uri? get trustedBaseUri =>
      trustedBaseUrl == null ? null : Uri.parse(trustedBaseUrl!);
}

abstract final class AiWebSearchProviderCatalog {
  static const brave = AiWebSearchProviderDescriptor(
    kind: AiWebSearchProviderKind.brave,
    label: 'Brave Search API',
    requiresCredential: true,
    hosted: true,
    trustedBaseUrl: 'https://api.search.brave.com/res/v1/web/search',
    documentationUrl:
        'https://api-dashboard.search.brave.com/api-reference/web/search/get',
    keyManagementUrl: 'https://api-dashboard.search.brave.com/app/keys',
    billingUrl: 'https://api-dashboard.search.brave.com/app/plans',
  );

  static const searxng = AiWebSearchProviderDescriptor(
    kind: AiWebSearchProviderKind.searxng,
    label: 'Self-hosted SearXNG',
    requiresCredential: false,
    hosted: false,
    documentationUrl: 'https://docs.searxng.org/dev/search_api.html',
  );

  static const values = [brave, searxng];

  static AiWebSearchProviderDescriptor descriptor(
    AiWebSearchProviderKind kind,
  ) => switch (kind) {
    AiWebSearchProviderKind.brave => brave,
    AiWebSearchProviderKind.searxng => searxng,
  };
}

final class AiWebSearchConnectionProfile {
  AiWebSearchConnectionProfile({
    required this.id,
    required this.name,
    required this.providerKind,
    required this.baseUrl,
    this.enabled = false,
    this.credentialReference,
    this.country = 'FI',
    this.searchLanguage = 'fi',
    this.safeSearch = AiWebSearchSafeSearch.moderate,
    this.requestTimeout = aiWebSearchDefaultTimeout,
  });

  final String id;
  final String name;
  final AiWebSearchProviderKind providerKind;
  final Uri baseUrl;
  final bool enabled;
  final String? credentialReference;
  final String country;
  final String searchLanguage;
  final AiWebSearchSafeSearch safeSearch;
  final Duration requestTimeout;

  AiWebSearchProviderDescriptor get provider =>
      AiWebSearchProviderCatalog.descriptor(providerKind);

  bool get hasRequiredCredential =>
      !provider.requiresCredential ||
      (credentialReference?.trim().isNotEmpty ?? false);

  bool get hasTrustedProviderConfiguration {
    if (baseUrl.hasQuery ||
        baseUrl.hasFragment ||
        baseUrl.userInfo.isNotEmpty) {
      return false;
    }
    final trusted = provider.trustedBaseUri;
    if (trusted == null) return true;
    return _normalizedEndpoint(baseUrl) == _normalizedEndpoint(trusted);
  }

  bool get isValid =>
      id.trim() == id &&
      id.isNotEmpty &&
      id.length <= aiWebSearchMaxProfileIdCharacters &&
      name.trim() == name &&
      name.isNotEmpty &&
      name.runes.length <= aiWebSearchMaxProfileNameCharacters &&
      baseUrl.toString().length <= aiWebSearchMaxEndpointCharacters &&
      (baseUrl.scheme == 'http' || baseUrl.scheme == 'https') &&
      baseUrl.host.isNotEmpty &&
      hasRequiredCredential &&
      (credentialReference == null ||
          credentialReference!.length <=
              aiWebSearchMaxCredentialReferenceCharacters) &&
      hasTrustedProviderConfiguration &&
      RegExp(r'^[A-Za-z]{2}$').hasMatch(country) &&
      RegExp(
        r'^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$',
      ).hasMatch(searchLanguage) &&
      requestTimeout > Duration.zero &&
      requestTimeout <= aiWebSearchMaxTimeout;

  /// Reusable provider credentials must never be exposed to a browser build.
  bool canSendRequests({required bool isWeb}) => enabled && isValid && !isWeb;

  AiWebSearchConnectionProfile copyWith({
    String? id,
    String? name,
    AiWebSearchProviderKind? providerKind,
    Uri? baseUrl,
    bool? enabled,
    String? credentialReference,
    bool clearCredentialReference = false,
    String? country,
    String? searchLanguage,
    AiWebSearchSafeSearch? safeSearch,
    Duration? requestTimeout,
  }) => AiWebSearchConnectionProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    providerKind: providerKind ?? this.providerKind,
    baseUrl: baseUrl ?? this.baseUrl,
    enabled: enabled ?? this.enabled,
    credentialReference:
        clearCredentialReference
            ? null
            : credentialReference ?? this.credentialReference,
    country: country ?? this.country,
    searchLanguage: searchLanguage ?? this.searchLanguage,
    safeSearch: safeSearch ?? this.safeSearch,
    requestTimeout: requestTimeout ?? this.requestTimeout,
  );
}

final class AiWebSearchRequest {
  AiWebSearchRequest({
    required String query,
    this.resultLimit = aiWebSearchMaxResults,
    this.freshness = AiWebSearchFreshness.any,
  }) : query = query.trim() {
    if (this.query.isEmpty ||
        this.query.runes.any((rune) => rune < 0x20 || rune == 0x7f) ||
        this.query.runes.length > aiWebSearchMaxQueryCharacters ||
        this.query.split(RegExp(r'\s+')).length > aiWebSearchMaxQueryWords) {
      throw ArgumentError.value(
        query,
        'query',
        'must contain 1 to $aiWebSearchMaxQueryWords words and at most '
            '$aiWebSearchMaxQueryCharacters characters',
      );
    }
    if (resultLimit < 1 || resultLimit > aiWebSearchMaxResults) {
      throw ArgumentError.value(
        resultLimit,
        'resultLimit',
        'must be between 1 and $aiWebSearchMaxResults',
      );
    }
  }

  final String query;
  final int resultLimit;
  final AiWebSearchFreshness freshness;
}

/// Accounting owned by one assistant turn. Executors reserve before network
/// access and record normalized output before returning it to a model.
final class AiWebSearchTurnBudget {
  int _callCount = 0;
  int _contextCharacters = 0;

  int get callCount => _callCount;
  int get contextCharacters => _contextCharacters;

  void reserveCall() {
    if (_callCount >= aiWebSearchMaxCallsPerTurn) {
      throw StateError(
        'The web-search call limit for this request has been reached.',
      );
    }
    _callCount++;
  }

  void recordContextCharacters(int characters) {
    if (characters < 0 ||
        _contextCharacters + characters > aiWebSearchMaxContextCharacters) {
      throw StateError(
        'The web-search context limit for this request has been reached.',
      );
    }
    _contextCharacters += characters;
  }
}

final class AiWebSearchResult {
  AiWebSearchResult({
    required this.sourceId,
    required this.title,
    required this.url,
    required this.snippet,
    required this.providerName,
    this.publishedAt,
  });

  final String sourceId;
  final String title;
  final Uri url;
  final String snippet;
  final String providerName;
  final DateTime? publishedAt;
}

final class AiWebSearchAuthorization {
  const AiWebSearchAuthorization({required this.connectionProfileId});

  final String connectionProfileId;

  bool authorizes(AiWebSearchConnectionProfile profile) =>
      connectionProfileId.isNotEmpty && connectionProfileId == profile.id;
}

abstract interface class AiWebSearchResponseHandle {
  Future<List<AiWebSearchResult>> get results;

  Future<void> cancel();
}

final class FutureAiWebSearchResponseHandle
    implements AiWebSearchResponseHandle {
  FutureAiWebSearchResponseHandle({
    required this.results,
    required Future<void> Function() onCancel,
  }) : _onCancel = onCancel;

  @override
  final Future<List<AiWebSearchResult>> results;

  final Future<void> Function() _onCancel;
  Future<void>? _cancellation;

  @override
  Future<void> cancel() => _cancellation ??= _onCancel();
}

String _normalizedEndpoint(Uri uri) {
  final path =
      uri.path.endsWith('/') && uri.path.length > 1
          ? uri.path.substring(0, uri.path.length - 1)
          : uri.path;
  return uri
      .replace(
        scheme: uri.scheme.toLowerCase(),
        host: uri.host.toLowerCase(),
        path: path,
        query: null,
        fragment: null,
      )
      .toString();
}
