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
  });

  const AiConnectionResult.connected({this.message = 'Connected', this.latency})
    : status = AiConnectionStatus.connected;

  final AiConnectionStatus status;
  final String message;
  final Duration? latency;

  bool get isConnected => status == AiConnectionStatus.connected;
}
