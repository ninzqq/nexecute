import 'package:nexecute/ai/domain/ai_diagnostic.dart';
import 'package:nexecute/ai/infrastructure/ai_transport_error_inspector.dart';
import 'package:nexecute/ai/infrastructure/ai_transport_error_kind.dart';

enum AiFailureOperation {
  connectionTest,
  modelDiscovery,
  responseStart,
  responseStream,
}

/// Converts low-level AI failures into user-safe, provider-neutral guidance.
final class AiFailureDiagnostics {
  AiFailureDiagnostics({bool? isWeb, bool? isSecureWebContext})
    : isWeb = isWeb ?? const bool.fromEnvironment('dart.library.js_interop'),
      isSecureWebContext =
          isSecureWebContext ??
          (const bool.fromEnvironment('dart.library.js_interop') &&
              Uri.base.scheme == 'https');

  final bool isWeb;
  final bool isSecureWebContext;

  AiDiagnostic invalidConfiguration() => AiDiagnostic(
    kind: AiDiagnosticKind.invalidConfiguration,
    title: 'Connection settings are incomplete',
    summary: 'The AI connection profile cannot be used as configured.',
    suggestions: const [
      'Check the endpoint URL, model, authentication method, and required credential.',
    ],
  );

  AiDiagnostic credentialUnavailable() => AiDiagnostic(
    kind: AiDiagnosticKind.invalidConfiguration,
    title: 'Credential unavailable',
    summary:
        'The configured endpoint credential is not available on this device.',
    suggestions: const [
      'Open AI Settings and add the credential again on this device.',
    ],
  );

  AiDiagnostic unsupported() => AiDiagnostic(
    kind: AiDiagnosticKind.unsupported,
    title: 'Configuration not supported',
    summary:
        'The selected protocol or authentication method is not supported yet.',
    suggestions: const [
      'Choose an implemented protocol and authentication method in AI Settings.',
    ],
  );

  AiDiagnostic modelNotFound() => AiDiagnostic(
    kind: AiDiagnosticKind.modelNotFound,
    title: 'Model not found',
    summary:
        'The endpoint is reachable, but the selected model is unavailable.',
    suggestions: const [
      'Discover models again or enter an installed model identifier.',
      'Confirm that the model has been downloaded on the AI server.',
    ],
  );

  AiDiagnostic timeout({required AiFailureOperation operation}) => AiDiagnostic(
    kind: AiDiagnosticKind.timeout,
    title:
        operation == AiFailureOperation.responseStream
            ? 'Response stalled'
            : 'Endpoint timed out',
    summary:
        operation == AiFailureOperation.responseStream
            ? 'The endpoint started responding but stopped sending data.'
            : 'The endpoint did not respond before the configured timeout.',
    suggestions: const [
      'Check whether the server or model is still starting.',
      'Increase the relevant timeout in AI Settings if the server is healthy but slow.',
    ],
  );

  AiDiagnostic invalidResponse({bool empty = false}) => AiDiagnostic(
    kind: AiDiagnosticKind.invalidResponse,
    title: empty ? 'Empty response' : 'Invalid endpoint response',
    summary:
        empty
            ? 'The endpoint completed without returning supported output.'
            : 'The endpoint returned data that does not match the selected protocol.',
    suggestions: const [
      'Check the selected protocol, base URL, and model compatibility.',
    ],
  );

  AiDiagnostic httpFailure(
    int statusCode, {
    required AiFailureOperation operation,
    String? safeProviderMessage,
  }) {
    if (statusCode == 401 || statusCode == 403) {
      return AiDiagnostic(
        kind: AiDiagnosticKind.authentication,
        title: 'Authentication failed',
        summary: 'The endpoint rejected the configured authentication.',
        suggestions: const [
          'Check the credential and authentication method in AI Settings.',
        ],
      );
    }
    if (statusCode == 404) {
      final modelWasMissing =
          operation != AiFailureOperation.modelDiscovery &&
          (safeProviderMessage?.toLowerCase().contains('model') ?? false);
      if (modelWasMissing) return modelNotFound();
      return AiDiagnostic(
        kind: AiDiagnosticKind.endpointNotFound,
        title: 'Endpoint path not found',
        summary:
            operation == AiFailureOperation.modelDiscovery
                ? 'The model-list endpoint was not found. For Ollama, use a base URL ending in /v1.'
                : 'The server does not expose the expected API path.',
        suggestions: const [
          'Check the base URL and its OpenAI-compatible /v1 path.',
        ],
      );
    }
    if (statusCode == 408) return timeout(operation: operation);
    if (statusCode == 429) {
      return AiDiagnostic(
        kind: AiDiagnosticKind.rateLimited,
        title: 'Endpoint is rate limiting requests',
        summary:
            'The endpoint temporarily refused the request because its request limit was reached.',
        suggestions: const ['Wait before trying again.'],
      );
    }
    if (statusCode >= 500) {
      return AiDiagnostic(
        kind: AiDiagnosticKind.serverUnavailable,
        title: 'AI server unavailable',
        summary: 'The endpoint reported a server-side failure.',
        suggestions: const [
          'Check whether the server and selected model are running or still starting.',
        ],
      );
    }
    if (statusCode == 400 ||
        statusCode == 405 ||
        statusCode == 415 ||
        statusCode == 422) {
      return AiDiagnostic(
        kind: AiDiagnosticKind.protocolIncompatible,
        title: 'Protocol incompatibility',
        summary:
            'The endpoint rejected the request format used by the selected protocol.',
        suggestions: const [
          'Check the selected protocol, endpoint API version, and model capabilities.',
        ],
      );
    }
    return unknown();
  }

  AiDiagnostic transportFailure(Object error, {required Uri endpoint}) {
    if (isWeb) {
      if (isSecureWebContext && endpoint.scheme == 'http') {
        return AiDiagnostic(
          kind: AiDiagnosticKind.browserMixedContent,
          title: 'Browser blocked an insecure endpoint',
          summary:
              'An HTTPS web application normally cannot call a plain HTTP AI endpoint.',
          suggestions: const [
            'Use an HTTPS endpoint or a same-origin user-owned gateway.',
          ],
        );
      }
      return AiDiagnostic(
        kind: AiDiagnosticKind.browserCorsOrNetwork,
        title: 'Browser could not access the endpoint',
        summary:
            'The browser does not reveal whether CORS, DNS, TLS, or network access blocked the request.',
        suggestions: const [
          'Verify HTTPS, DNS, and certificate validity.',
          'Allow the web application origin in the endpoint CORS configuration.',
        ],
      );
    }

    final transportKind = inspectAiTransportError(error);
    if (transportKind == AiTransportErrorKind.tls) {
      return AiDiagnostic(
        kind: AiDiagnosticKind.tls,
        title: 'Secure connection failed',
        summary:
            'The device could not establish a trusted TLS connection to the endpoint.',
        suggestions: const [
          'Check the certificate hostname, validity period, trust chain, and device clock.',
        ],
      );
    }
    if (transportKind == AiTransportErrorKind.dns) {
      return AiDiagnostic(
        kind: AiDiagnosticKind.dns,
        title: 'Endpoint name not found',
        summary: 'The device could not resolve the endpoint hostname.',
        suggestions: const [
          'Check the hostname, DNS configuration, and Tailscale MagicDNS connectivity.',
        ],
      );
    }
    if (_isLocalNetworkHost(endpoint.host)) {
      return AiDiagnostic(
        kind: AiDiagnosticKind.localNetwork,
        title: 'Local endpoint unavailable',
        summary:
            'The device could not connect to the configured local or private-network address.',
        suggestions: [
          if (_isLoopbackHost(endpoint.host))
            'Use the AI server computer address; localhost refers to this device.',
          'Check that the server is running and that this device is on the required LAN or tailnet.',
        ],
      );
    }
    return AiDiagnostic(
      kind: AiDiagnosticKind.unreachable,
      title: 'Endpoint unreachable',
      summary:
          'The device could not establish a network connection to the endpoint.',
      suggestions: const [
        'Check the endpoint address, server status, and this device network connection.',
      ],
    );
  }

  AiDiagnostic? recognizedNativeTransportFailure(
    Object error, {
    required Uri endpoint,
  }) {
    if (isWeb ||
        inspectAiTransportError(error) == AiTransportErrorKind.unknown) {
      return null;
    }
    return transportFailure(error, endpoint: endpoint);
  }

  AiDiagnostic providerFailure() => AiDiagnostic(
    kind: AiDiagnosticKind.unknown,
    title: 'Endpoint rejected the request',
    summary:
        'The endpoint reported a failure that Nexecute could not classify safely.',
    suggestions: const [
      'Check the connection settings and review the AI server logs locally.',
    ],
  );

  AiDiagnostic unknown() => AiDiagnostic(
    kind: AiDiagnosticKind.unknown,
    title: 'AI request failed',
    summary: 'The AI operation failed for an unknown reason.',
    suggestions: const [
      'Test the connection and review the profile in AI Settings.',
    ],
  );
}

bool _isLoopbackHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1';
}

bool _isLocalNetworkHost(String host) {
  final normalized = host.toLowerCase();
  if (_isLoopbackHost(normalized) ||
      normalized.endsWith('.local') ||
      normalized.endsWith('.ts.net') ||
      normalized.startsWith('fc') ||
      normalized.startsWith('fd') ||
      normalized.startsWith('fe80:')) {
    return true;
  }
  final octets = normalized.split('.').map(int.tryParse).toList();
  if (octets.length != 4 || octets.any((octet) => octet == null)) return false;
  final first = octets[0]!;
  final second = octets[1]!;
  return first == 10 ||
      first == 127 ||
      (first == 169 && second == 254) ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 192 && second == 168) ||
      (first == 100 && second >= 64 && second <= 127);
}
