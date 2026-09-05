import 'package:nexecute/ai/domain/ai_protocol.dart';

const aiDefaultContextWindowTokens = 8192;
const aiMaxContextWindowTokens = 2097152;

const aiDefaultMaxOutputTokens = 1024;
const aiMinOutputTokens = 1;
const aiMaxOutputTokens = 131072;
const aiDefaultConnectionTimeout = Duration(seconds: 120);
const aiDefaultResponseIdleTimeout = Duration(seconds: 90);
const aiMinTimeoutSeconds = 5;
const aiMaxTimeoutSeconds = 900;
const aiMaxSystemPromptCharacters = 4000;

/// Default user-editable profile preferences.
///
/// The historical field name is retained for stored-profile compatibility.
/// Safety and authorization rules live in the immutable prompt composer.
const aiDefaultSystemPrompt =
    '''Reply in the same language as the user unless they ask otherwise.
Be concise, practical, and honest.''';

enum AiReasoningEffort { automatic, none, low, medium, high }

enum AiCapabilityState {
  protocolDefault,
  confirmedSupported,
  confirmedUnsupported,
  unconfirmed,
}

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
    this.contextWindowTokens = aiDefaultContextWindowTokens,
    this.allowMultipleSkills = false,
    this.connectionTimeout = aiDefaultConnectionTimeout,
    this.responseIdleTimeout = aiDefaultResponseIdleTimeout,
    this.systemPrompt = aiDefaultSystemPrompt,
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
  final int contextWindowTokens;
  final bool allowMultipleSkills;
  final Duration connectionTimeout;
  final Duration responseIdleTimeout;
  final String systemPrompt;
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
      contextWindowTokens >= 2048 &&
      contextWindowTokens <= aiMaxContextWindowTokens &&
      maxOutputTokens >= aiMinOutputTokens &&
      maxOutputTokens <= aiMaxOutputTokens &&
      connectionTimeout > Duration.zero &&
      connectionTimeout <= Duration(seconds: aiMaxTimeoutSeconds) &&
      responseIdleTimeout > Duration.zero &&
      responseIdleTimeout <= Duration(seconds: aiMaxTimeoutSeconds) &&
      systemPrompt.length <= aiMaxSystemPromptCharacters &&
      hasRequiredCredential;

  AiCapabilityState capabilityState(AiCapability capability) {
    final override = capabilityOverrides[capability];
    if (override != null) {
      return override
          ? AiCapabilityState.confirmedSupported
          : AiCapabilityState.confirmedUnsupported;
    }
    return protocol.defaultCapabilities.contains(capability)
        ? AiCapabilityState.protocolDefault
        : AiCapabilityState.unconfirmed;
  }

  bool supports(AiCapability capability) => switch (capabilityState(
    capability,
  )) {
    AiCapabilityState.protocolDefault ||
    AiCapabilityState.confirmedSupported => true,
    AiCapabilityState.confirmedUnsupported ||
    AiCapabilityState.unconfirmed => false,
  };

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
    int? contextWindowTokens,
    bool? allowMultipleSkills,
    Duration? connectionTimeout,
    Duration? responseIdleTimeout,
    String? systemPrompt,
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
      contextWindowTokens: contextWindowTokens ?? this.contextWindowTokens,
      allowMultipleSkills: allowMultipleSkills ?? this.allowMultipleSkills,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      responseIdleTimeout: responseIdleTimeout ?? this.responseIdleTimeout,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      capabilityOverrides: capabilityOverrides ?? this.capabilityOverrides,
    );
  }
}
