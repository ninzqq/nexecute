enum AiProtocol {
  openAiCompatibleChat,
  openAiResponses,
  anthropicMessages,
  nexecuteGateway,
}

enum AiAuthenticationMode { none, bearerToken, apiKeyHeader, gatewaySession }

extension AiAuthenticationModeRequirements on AiAuthenticationMode {
  bool get requiresCredential => switch (this) {
    AiAuthenticationMode.none || AiAuthenticationMode.gatewaySession => false,
    AiAuthenticationMode.bearerToken ||
    AiAuthenticationMode.apiKeyHeader => true,
  };
}

enum AiCapability {
  streaming,
  modelDiscovery,
  reasoning,
  tools,
  structuredOutput,
}

extension AiProtocolCapabilities on AiProtocol {
  Set<AiCapability> get defaultCapabilities => switch (this) {
    AiProtocol.openAiCompatibleChat => const {
      AiCapability.streaming,
      AiCapability.modelDiscovery,
    },
    AiProtocol.openAiResponses => const {
      AiCapability.streaming,
      AiCapability.modelDiscovery,
      AiCapability.tools,
      AiCapability.structuredOutput,
    },
    AiProtocol.anthropicMessages => const {
      AiCapability.streaming,
      AiCapability.modelDiscovery,
      AiCapability.tools,
    },
    AiProtocol.nexecuteGateway => AiCapability.values.toSet(),
  };
}
