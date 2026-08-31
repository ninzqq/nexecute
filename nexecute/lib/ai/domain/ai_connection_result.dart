import 'package:nexecute/ai/domain/ai_diagnostic.dart';

enum AiConnectionStatus {
  connected,
  invalidConfiguration,
  authenticationFailed,
  modelNotFound,
  timeout,
  unreachable,
  unsupported,
  failed,
}

class AiConnectionResult {
  const AiConnectionResult({
    required this.status,
    required this.message,
    this.latency,
    this.diagnostic,
  });

  const AiConnectionResult.connected({this.message = 'Connected', this.latency})
    : status = AiConnectionStatus.connected,
      diagnostic = null;

  final AiConnectionStatus status;
  final String message;
  final Duration? latency;
  final AiDiagnostic? diagnostic;

  bool get isConnected => status == AiConnectionStatus.connected;
}
