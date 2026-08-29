import 'package:nexecute/ai/domain/ai_protocol.dart';

class AiConnectionProfile {
  AiConnectionProfile({
    required this.id,
    required this.name,
    required this.protocol,
    required this.baseUrl,
    required this.modelId,
    this.authenticationMode = AiAuthenticationMode.none,
    this.credentialReference,
    Map<AiCapability, bool> capabilityOverrides = const {},
  }) : capabilityOverrides = Map.unmodifiable(capabilityOverrides);

  final String id;
  final String name;
  final AiProtocol protocol;
  final Uri baseUrl;
  final String modelId;
  final AiAuthenticationMode authenticationMode;
  final String? credentialReference;
  final Map<AiCapability, bool> capabilityOverrides;

  bool get hasRequiredCredential =>
      !authenticationMode.requiresCredential ||
      (credentialReference?.trim().isNotEmpty ?? false);

  bool get isValid =>
      id.trim().isNotEmpty &&
      name.trim().isNotEmpty &&
      baseUrl.hasScheme &&
      baseUrl.host.isNotEmpty &&
      modelId.trim().isNotEmpty &&
      hasRequiredCredential;

  AiConnectionProfile copyWith({
    String? id,
    String? name,
    AiProtocol? protocol,
    Uri? baseUrl,
    String? modelId,
    AiAuthenticationMode? authenticationMode,
    String? credentialReference,
    bool clearCredentialReference = false,
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
      capabilityOverrides: capabilityOverrides ?? this.capabilityOverrides,
    );
  }
}
