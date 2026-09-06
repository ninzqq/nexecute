import 'package:flutter/foundation.dart';
import 'package:nexecute/ai/domain/ai_chat_request.dart';
import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/ai/domain/ai_connection_result.dart';
import 'package:nexecute/ai/domain/ai_diagnostic.dart';
import 'package:nexecute/ai/domain/ai_model_info.dart';
import 'package:nexecute/ai/domain/ai_protocol.dart';
import 'package:nexecute/ai/domain/ai_stream_event.dart';
import 'package:nexecute/ai/repositories/ai_assistant_repository.dart';
import 'package:nexecute/ai/repositories/ai_response_handle.dart';

final class RoutingAiAssistantRepository implements AiAssistantRepository {
  RoutingAiAssistantRepository({
    required Map<AiProtocol, AiAssistantRepository> adapters,
    bool? isWeb,
    Iterable<void Function()> disposers = const [],
  }) : _adapters = Map.unmodifiable(adapters),
       _isWeb = isWeb ?? kIsWeb,
       _disposers = List.unmodifiable(disposers);

  final Map<AiProtocol, AiAssistantRepository> _adapters;
  final bool _isWeb;
  final List<void Function()> _disposers;

  @override
  Future<AiConnectionResult> testConnection(AiConnectionProfile profile) {
    final failure = _resolveFailure(profile);
    if (failure != null) return Future.value(failure.connectionResult);
    return _adapters[profile.protocol]!.testConnection(profile);
  }

  @override
  Future<List<AiModelInfo>> listModels(AiConnectionProfile profile) {
    final failure = _resolveFailure(profile);
    if (failure != null) {
      throw AiDiagnosticException(
        diagnostic: failure.diagnostic,
        message: failure.message,
      );
    }
    return _adapters[profile.protocol]!.listModels(profile);
  }

  @override
  Future<AiResponseHandle> startResponse(AiChatRequest request) {
    final failure = _resolveFailure(request.connectionProfile);
    if (failure == null) {
      return _adapters[request.connectionProfile.protocol]!.startResponse(
        request,
      );
    }
    final error = StateError(failure.message);
    return Future.value(
      StreamAiResponseHandle(
        events: Stream.value(
          AiResponseFailed(
            error: error,
            message: failure.message,
            code: failure.diagnostic.code,
            retryable: false,
            diagnostic: failure.diagnostic,
          ),
        ),
        onCancel: () async {},
      ),
    );
  }

  void dispose() {
    for (final dispose in _disposers.reversed) {
      dispose();
    }
  }

  _RoutingFailure? _resolveFailure(AiConnectionProfile profile) {
    if (!profile.hasTrustedProviderConfiguration) {
      return _RoutingFailure.invalid(
        'The provider endpoint or protocol does not match its trusted preset.',
      );
    }
    if (profile.provider.hosted && _isWeb) {
      return _RoutingFailure.invalid(
        'Direct cloud-provider credentials are unavailable on Web. Use a user-owned gateway.',
      );
    }
    if (profile.provider.hosted && !profile.hostedInferenceEnabled) {
      return _RoutingFailure.invalid(
        'Cloud requests are disabled for this connection. Review and enable cloud use in Settings.',
      );
    }
    if (_adapters[profile.protocol] == null) {
      return _RoutingFailure.unsupported(
        'The ${profile.provider.label} protocol adapter is not implemented yet.',
      );
    }
    return null;
  }
}

final class _RoutingFailure {
  _RoutingFailure({
    required this.status,
    required this.message,
    required this.diagnostic,
  });

  factory _RoutingFailure.invalid(String message) => _RoutingFailure(
    status: AiConnectionStatus.invalidConfiguration,
    message: message,
    diagnostic: AiDiagnostic(
      kind: AiDiagnosticKind.invalidConfiguration,
      title: 'Connection setup needs attention',
      summary: message,
      suggestions: const ['Review this connection in AI Settings.'],
    ),
  );

  factory _RoutingFailure.unsupported(String message) => _RoutingFailure(
    status: AiConnectionStatus.unsupported,
    message: message,
    diagnostic: AiDiagnostic(
      kind: AiDiagnosticKind.unsupported,
      title: 'Provider is not available yet',
      summary: message,
    ),
  );

  final AiConnectionStatus status;
  final String message;
  final AiDiagnostic diagnostic;

  AiConnectionResult get connectionResult => AiConnectionResult(
    status: status,
    message: message,
    diagnostic: diagnostic,
  );
}
