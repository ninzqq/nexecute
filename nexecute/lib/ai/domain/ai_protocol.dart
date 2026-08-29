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

enum AiCapability { streaming, modelDiscovery, tools, structuredOutput }
