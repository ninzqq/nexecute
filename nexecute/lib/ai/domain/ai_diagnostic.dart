/// A stable, provider-neutral category for an actionable AI failure.
///
/// Categories describe what the user can investigate without exposing
/// provider-specific exceptions, response bodies, credentials, or endpoint
/// details.
enum AiDiagnosticKind {
  invalidConfiguration,
  dns,
  tls,
  browserMixedContent,
  browserCorsOrNetwork,
  localNetwork,
  authentication,
  endpointNotFound,
  modelNotFound,
  timeout,
  rateLimited,
  serverUnavailable,
  protocolIncompatible,
  invalidResponse,
  unreachable,
  unsupported,
  unknown;

  /// Stable identifier suitable for tests and presentation branching.
  String get code => switch (this) {
    AiDiagnosticKind.invalidConfiguration => 'invalid_configuration',
    AiDiagnosticKind.dns => 'dns',
    AiDiagnosticKind.tls => 'tls',
    AiDiagnosticKind.browserMixedContent => 'browser_mixed_content',
    AiDiagnosticKind.browserCorsOrNetwork => 'browser_cors_or_network',
    AiDiagnosticKind.localNetwork => 'local_network',
    AiDiagnosticKind.authentication => 'authentication',
    AiDiagnosticKind.endpointNotFound => 'endpoint_not_found',
    AiDiagnosticKind.modelNotFound => 'model_not_found',
    AiDiagnosticKind.timeout => 'timeout',
    AiDiagnosticKind.rateLimited => 'rate_limited',
    AiDiagnosticKind.serverUnavailable => 'server_unavailable',
    AiDiagnosticKind.protocolIncompatible => 'protocol_incompatible',
    AiDiagnosticKind.invalidResponse => 'invalid_response',
    AiDiagnosticKind.unreachable => 'unreachable',
    AiDiagnosticKind.unsupported => 'unsupported',
    AiDiagnosticKind.unknown => 'unknown',
  };
}

/// User-safe diagnostic content produced after an AI operation fails.
///
/// [summary] explains the observed problem. [suggestions] contains concrete
/// checks a user can perform. Callers must never place credentials, raw
/// provider payloads, or sensitive endpoint details in either field.
final class AiDiagnostic {
  AiDiagnostic({
    required this.kind,
    required String title,
    required String summary,
    List<String> suggestions = const [],
  }) : title = _requiredText(title, 'title'),
       summary = _requiredText(summary, 'summary'),
       suggestions = List.unmodifiable(
         suggestions.map((value) => _requiredText(value, 'suggestions')),
       );

  final AiDiagnosticKind kind;
  final String title;
  final String summary;
  final List<String> suggestions;

  String get code => kind.code;

  static String _requiredText(String value, String name) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, name, 'Use non-empty user-safe text.');
    }
    return normalized;
  }
}

/// An operation failure that carries only a user-safe diagnostic across an
/// application boundary while retaining its original cause for local handling.
final class AiDiagnosticException implements Exception {
  AiDiagnosticException({required this.diagnostic, String? message, this.cause})
    : message = AiDiagnostic._requiredText(
        message ?? diagnostic.summary,
        'message',
      );

  final AiDiagnostic diagnostic;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
