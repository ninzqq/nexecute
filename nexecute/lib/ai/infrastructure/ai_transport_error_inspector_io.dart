import 'dart:io';

import 'package:nexecute/ai/infrastructure/ai_transport_error_kind.dart';

AiTransportErrorKind inspectAiTransportError(Object error) {
  if (error is TlsException) {
    return AiTransportErrorKind.tls;
  }
  if (error is! SocketException) return AiTransportErrorKind.unknown;

  final description =
      [
        error.message,
        error.osError?.message,
      ].whereType<String>().join(' ').toLowerCase();
  if (_containsAny(description, const [
    'failed host lookup',
    'name or service not known',
    'nodename nor servname provided',
    'no address associated with hostname',
    'temporary failure in name resolution',
  ])) {
    return AiTransportErrorKind.dns;
  }
  if (description.contains('connection refused')) {
    return AiTransportErrorKind.connectionRefused;
  }
  return AiTransportErrorKind.unreachable;
}

bool _containsAny(String value, Iterable<String> candidates) =>
    candidates.any(value.contains);
