import 'package:nexecute/ai/domain/ai_protocol.dart';

enum AiProviderKind { custom, googleGemini, openAI, anthropic }

const nexecuteGeminiApiClient = 'nexecute-oai/1.0.0';

final class AiProviderDescriptor {
  const AiProviderDescriptor({
    required this.kind,
    required this.label,
    required this.protocol,
    required this.authenticationMode,
    required this.hosted,
    this.trustedBaseUrl,
    this.documentationUrl,
    this.keyManagementUrl,
    this.billingUrl,
    this.requestHeaders = const {},
  });

  final AiProviderKind kind;
  final String label;
  final AiProtocol protocol;
  final AiAuthenticationMode authenticationMode;
  final bool hosted;
  final String? trustedBaseUrl;
  final String? documentationUrl;
  final String? keyManagementUrl;
  final String? billingUrl;
  final Map<String, String> requestHeaders;

  Uri? get trustedBaseUri =>
      trustedBaseUrl == null ? null : Uri.parse(trustedBaseUrl!);

  bool matchesTrustedConfiguration({
    required AiProtocol candidateProtocol,
    required AiAuthenticationMode candidateAuthenticationMode,
    required Uri candidateBaseUrl,
  }) {
    if (!hosted) return true;
    if (candidateBaseUrl.hasQuery ||
        candidateBaseUrl.hasFragment ||
        candidateBaseUrl.userInfo.isNotEmpty) {
      return false;
    }
    return candidateProtocol == protocol &&
        candidateAuthenticationMode == authenticationMode &&
        _normalizedEndpoint(candidateBaseUrl) ==
            _normalizedEndpoint(trustedBaseUri!);
  }
}

abstract final class AiProviderCatalog {
  static const custom = AiProviderDescriptor(
    kind: AiProviderKind.custom,
    label: 'Custom / local',
    protocol: AiProtocol.openAiCompatibleChat,
    authenticationMode: AiAuthenticationMode.none,
    hosted: false,
  );

  static const googleGemini = AiProviderDescriptor(
    kind: AiProviderKind.googleGemini,
    label: 'Google Gemini API',
    protocol: AiProtocol.openAiCompatibleChat,
    authenticationMode: AiAuthenticationMode.bearerToken,
    hosted: true,
    trustedBaseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai/',
    documentationUrl: 'https://ai.google.dev/gemini-api/docs',
    keyManagementUrl: 'https://aistudio.google.com/app/apikey',
    billingUrl: 'https://ai.google.dev/gemini-api/docs/pricing',
    requestHeaders: {'x-goog-api-client': nexecuteGeminiApiClient},
  );

  static const openAI = AiProviderDescriptor(
    kind: AiProviderKind.openAI,
    label: 'OpenAI API',
    protocol: AiProtocol.openAiResponses,
    authenticationMode: AiAuthenticationMode.bearerToken,
    hosted: true,
    trustedBaseUrl: 'https://api.openai.com/v1/',
    documentationUrl: 'https://developers.openai.com/api/docs',
    keyManagementUrl: 'https://platform.openai.com/api-keys',
    billingUrl: 'https://platform.openai.com/settings/organization/billing',
  );

  static const anthropic = AiProviderDescriptor(
    kind: AiProviderKind.anthropic,
    label: 'Anthropic Claude API',
    protocol: AiProtocol.anthropicMessages,
    authenticationMode: AiAuthenticationMode.bearerToken,
    hosted: true,
    trustedBaseUrl: 'https://api.anthropic.com/v1/',
    documentationUrl: 'https://platform.claude.com/docs',
    keyManagementUrl: 'https://platform.claude.com/settings/keys',
    billingUrl: 'https://platform.claude.com/settings/billing',
  );

  static const values = [custom, googleGemini, openAI, anthropic];

  static AiProviderDescriptor descriptor(AiProviderKind kind) => switch (kind) {
    AiProviderKind.custom => custom,
    AiProviderKind.googleGemini => googleGemini,
    AiProviderKind.openAI => openAI,
    AiProviderKind.anthropic => anthropic,
  };
}

String _normalizedEndpoint(Uri uri) {
  final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
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
