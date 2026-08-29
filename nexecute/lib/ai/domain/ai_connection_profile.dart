import 'package:nexecute/ai/domain/ai_protocol.dart';

const aiDefaultMaxOutputTokens = 1024;
const aiMinOutputTokens = 1;
const aiMaxOutputTokens = 131072;
const aiDefaultConnectionTimeout = Duration(seconds: 120);
const aiDefaultResponseIdleTimeout = Duration(seconds: 90);
const aiMinTimeoutSeconds = 5;
const aiMaxTimeoutSeconds = 900;

enum AiReasoningEffort { automatic, none, low, medium, high }

class AiConnectionProfile {
  AiConnectionProfile({
    required this.id,
    required this.name,
    required this.protocol,
    required this.baseUrl,
    required this.modelId,
    this.authenticationMode = AiAuthenticationMode.none,
    this.credentialReference,
    this.reasoningEffort = AiReasoningEffort.automatic,
    this.maxOutputTokens = aiDefaultMaxOutputTokens,
    this.connectionTimeout = aiDefaultConnectionTimeout,
    this.responseIdleTimeout = aiDefaultResponseIdleTimeout,
    Map<AiCapability, bool> capabilityOverrides = const {},
  }) : capabilityOverrides = Map.unmodifiable(capabilityOverrides);

  final String id;
  final String name;
  final AiProtocol protocol;
  final Uri baseUrl;
  final String modelId;
  final AiAuthenticationMode authenticationMode;
  final String? credentialReference;
  final AiReasoningEffort reasoningEffort;
  final int maxOutputTokens;
  final Duration connectionTimeout;
  final Duration responseIdleTimeout;
  final Map<AiCapability, bool> capabilityOverrides;

  bool get hasRequiredCredential =>
      !authenticationMode.requiresCredential ||
      (credentialReference?.trim().isNotEmpty ?? false);

  bool get isValid =>
      id.trim().isNotEmpty &&
      name.trim().isNotEmpty &&
      baseUrl.hasScheme &&
      (baseUrl.scheme == 'http' || baseUrl.scheme == 'https') &&
      baseUrl.host.isNotEmpty &&
      modelId.trim().isNotEmpty &&
      maxOutputTokens >= aiMinOutputTokens &&
      maxOutputTokens <= aiMaxOutputTokens &&
      connectionTimeout > Duration.zero &&
      connectionTimeout <= Duration(seconds: aiMaxTimeoutSeconds) &&
      responseIdleTimeout > Duration.zero &&
      responseIdleTimeout <= Duration(seconds: aiMaxTimeoutSeconds) &&
      hasRequiredCredential;

  bool supports(AiCapability capability) =>
      capabilityOverrides[capability] ??
      protocol.defaultCapabilities.contains(capability);

  AiConnectionProfile copyWith({
    String? id,
    String? name,
    AiProtocol? protocol,
    Uri? baseUrl,
    String? modelId,
    AiAuthenticationMode? authenticationMode,
    String? credentialReference,
    bool clearCredentialReference = false,
    AiReasoningEffort? reasoningEffort,
    int? maxOutputTokens,
    Duration? connectionTimeout,
    Duration? responseIdleTimeout,
    Map<AiCapability, bool>? capabilityOverrides,
  }) {
    return AiConnectionProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      baseUrl: baseUrl ?? this.baseUrl,
      modelId: modelId ?? this.modelId,
      authenticationMode: authenticationMode ?? this.authenticationMode,
      credentialReference:
          clearCredentialReference
              ? null
              : credentialReference ?? this.credentialReference,
      reasoningEffort: reasoningEffort ?? this.reasoningEffort,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      responseIdleTimeout: responseIdleTimeout ?? this.responseIdleTimeout,
      capabilityOverrides: capabilityOverrides ?? this.capabilityOverrides,
    );
  }
}
