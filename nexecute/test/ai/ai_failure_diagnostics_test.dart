import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:nexecute/ai/ai.dart';
import 'package:test/test.dart';

void main() {
  group('HTTP failures', () {
    final diagnostics = AiFailureDiagnostics(
      isWeb: false,
      isSecureWebContext: false,
    );

    test(
      'classifies authentication, endpoint, timeout, and capacity failures',
      () {
        expect(
          diagnostics
              .httpFailure(401, operation: AiFailureOperation.connectionTest)
              .kind,
          AiDiagnosticKind.authentication,
        );
        expect(
          diagnostics
              .httpFailure(404, operation: AiFailureOperation.modelDiscovery)
              .kind,
          AiDiagnosticKind.endpointNotFound,
        );
        expect(
          diagnostics
              .httpFailure(408, operation: AiFailureOperation.responseStart)
              .kind,
          AiDiagnosticKind.timeout,
        );
        expect(
          diagnostics
              .httpFailure(429, operation: AiFailureOperation.responseStart)
              .kind,
          AiDiagnosticKind.rateLimited,
        );
        expect(
          diagnostics
              .httpFailure(503, operation: AiFailureOperation.responseStart)
              .kind,
          AiDiagnosticKind.serverUnavailable,
        );
      },
    );

    test('distinguishes a missing model from a missing response endpoint', () {
      expect(
        diagnostics
            .httpFailure(
              404,
              operation: AiFailureOperation.responseStart,
              safeProviderMessage: 'model runner not found',
            )
            .kind,
        AiDiagnosticKind.modelNotFound,
      );
      expect(
        diagnostics
            .httpFailure(
              404,
              operation: AiFailureOperation.responseStart,
              safeProviderMessage: 'route not found',
            )
            .kind,
        AiDiagnosticKind.endpointNotFound,
      );
    });

    test('classifies request-format rejection as protocol incompatibility', () {
      for (final statusCode in [400, 405, 415, 422]) {
        expect(
          diagnostics
              .httpFailure(
                statusCode,
                operation: AiFailureOperation.responseStart,
              )
              .kind,
          AiDiagnosticKind.protocolIncompatible,
        );
      }
    });
  });

  group('transport failures', () {
    test('reports mixed content only when a secure web app calls HTTP', () {
      final secureWeb = AiFailureDiagnostics(
        isWeb: true,
        isSecureWebContext: true,
      );
      final diagnostic = secureWeb.transportFailure(
        http.ClientException('opaque browser failure'),
        endpoint: Uri.parse('http://ai.example.test/v1'),
      );

      expect(diagnostic.kind, AiDiagnosticKind.browserMixedContent);
    });

    test('keeps opaque browser transport failures intentionally uncertain', () {
      final web = AiFailureDiagnostics(isWeb: true, isSecureWebContext: false);
      final diagnostic = web.transportFailure(
        http.ClientException('TypeError: Failed to fetch private detail'),
        endpoint: Uri.parse('https://ai.example.test/v1'),
      );

      expect(diagnostic.kind, AiDiagnosticKind.browserCorsOrNetwork);
      expect(diagnostic.summary, isNot(contains('private detail')));
    });

    test('classifies native DNS and TLS errors without exposing details', () {
      final native = AiFailureDiagnostics(
        isWeb: false,
        isSecureWebContext: false,
      );
      final dns = native.transportFailure(
        const SocketException('Failed host lookup: secret.internal'),
        endpoint: Uri.parse('https://ai.example.test/v1'),
      );
      final tls = native.transportFailure(
        const HandshakeException('CERTIFICATE_VERIFY_FAILED secret.internal'),
        endpoint: Uri.parse('https://ai.example.test/v1'),
      );

      expect(dns.kind, AiDiagnosticKind.dns);
      expect(tls.kind, AiDiagnosticKind.tls);
      expect(dns.summary, isNot(contains('secret.internal')));
      expect(tls.summary, isNot(contains('secret.internal')));
    });

    test('adds local-network guidance for private and loopback addresses', () {
      final native = AiFailureDiagnostics(
        isWeb: false,
        isSecureWebContext: false,
      );
      final privateAddress = native.transportFailure(
        http.ClientException('offline'),
        endpoint: Uri.parse('http://192.168.1.2:11434/v1'),
      );
      final loopback = native.transportFailure(
        http.ClientException('offline'),
        endpoint: Uri.parse('http://localhost:11434/v1'),
      );

      expect(privateAddress.kind, AiDiagnosticKind.localNetwork);
      expect(loopback.kind, AiDiagnosticKind.localNetwork);
      expect(loopback.suggestions.join(' '), contains('localhost'));
    });
  });

  test('uses distinct timeout guidance after a stream has started', () {
    final diagnostics = AiFailureDiagnostics(
      isWeb: false,
      isSecureWebContext: false,
    );

    expect(
      diagnostics.timeout(operation: AiFailureOperation.responseStart).title,
      'Endpoint timed out',
    );
    expect(
      diagnostics.timeout(operation: AiFailureOperation.responseStream).title,
      'Response stalled',
    );
  });
}
