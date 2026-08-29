import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nexecute/ai/domain/ai_chat_message.dart';
import 'package:nexecute/ai/domain/ai_chat_request.dart';
import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/ai/domain/ai_connection_result.dart';
import 'package:nexecute/ai/domain/ai_model_info.dart';
import 'package:nexecute/ai/domain/ai_protocol.dart';
import 'package:nexecute/ai/domain/ai_stream_event.dart';
import 'package:nexecute/ai/repositories/ai_assistant_repository.dart';
import 'package:nexecute/ai/repositories/ai_response_handle.dart';

class OpenAiCompatibleAssistantRepository implements AiAssistantRepository {
  OpenAiCompatibleAssistantRepository({
    http.Client? client,
    this.connectionTimeout = const Duration(seconds: 20),
    this.responseIdleTimeout = const Duration(seconds: 90),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration connectionTimeout;
  final Duration responseIdleTimeout;

  @override
  Future<AiConnectionResult> testConnection(AiConnectionProfile profile) async {
    final configurationError = _configurationError(profile);
    if (configurationError != null) return configurationError;

    final stopwatch = Stopwatch()..start();
    try {
      final models = await listModels(profile).timeout(connectionTimeout);
      stopwatch.stop();
      if (models.isNotEmpty &&
          !models.any((model) => model.id == profile.modelId)) {
        return AiConnectionResult(
          status: AiConnectionStatus.modelNotFound,
          message: 'Connected, but model “${profile.modelId}” was not found.',
          latency: stopwatch.elapsed,
        );
      }
      return AiConnectionResult.connected(latency: stopwatch.elapsed);
    } on TimeoutException {
      return const AiConnectionResult(
        status: AiConnectionStatus.timeout,
        message: 'The AI endpoint did not respond in time.',
      );
    } on OpenAiCompatibleHttpException catch (error) {
      final status = switch (error.statusCode) {
        401 || 403 => AiConnectionStatus.authenticationFailed,
        404 => AiConnectionStatus.invalidConfiguration,
        _ => AiConnectionStatus.failed,
      };
      final message =
          error.statusCode == 404
              ? 'The model-list endpoint was not found. For Ollama, use a '
                  'base URL ending in /v1.'
              : error.message;
      return AiConnectionResult(status: status, message: message);
    } on http.ClientException catch (error) {
      return AiConnectionResult(
        status: AiConnectionStatus.unreachable,
        message: 'Could not reach the AI endpoint: ${error.message}',
      );
    } catch (error) {
      return AiConnectionResult(
        status: AiConnectionStatus.failed,
        message: 'Connection test failed: $error',
      );
    }
  }

  @override
  Future<List<AiModelInfo>> listModels(AiConnectionProfile profile) async {
    final configurationError = _configurationError(profile);
    if (configurationError != null) {
      throw StateError(configurationError.message);
    }
    final response = await _client
        .get(_endpoint(profile.baseUrl, 'models'), headers: _headers(profile))
        .timeout(connectionTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenAiCompatibleHttpException(
        response.statusCode,
        _errorMessage(response.body, response.statusCode),
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map || body['data'] is! List) {
      throw const FormatException(
        'The endpoint returned an invalid model list.',
      );
    }
    return List.unmodifiable(
      (body['data'] as List)
          .whereType<Map>()
          .map(
            (model) => AiModelInfo(
              id: model['id']?.toString() ?? '',
              displayName: model['name']?.toString(),
              ownedBy: model['owned_by']?.toString(),
              capabilities: profile.protocol.defaultCapabilities,
            ),
          )
          .where((model) => model.id.isNotEmpty),
    );
  }

  @override
  Future<AiResponseHandle> startResponse(AiChatRequest request) async {
    final abort = Completer<void>();
    return StreamAiResponseHandle(
      events: _streamResponse(request, abort.future),
      onCancel: () async {
        if (!abort.isCompleted) abort.complete();
      },
    );
  }

  Stream<AiStreamEvent> _streamResponse(
    AiChatRequest request,
    Future<void> abortTrigger,
  ) async* {
    final profile = request.connectionProfile;
    final configurationError = _configurationError(profile);
    if (configurationError != null) {
      yield AiResponseFailed(
        error: StateError(configurationError.message),
        message: configurationError.message,
      );
      return;
    }

    final httpRequest = http.AbortableRequest(
      'POST',
      _endpoint(profile.baseUrl, 'chat/completions'),
      abortTrigger: abortTrigger,
    );
    httpRequest.headers.addAll(_headers(profile));
    httpRequest.body = jsonEncode({
      'model': profile.modelId,
      'messages': [
        if (request.systemInstruction?.trim().isNotEmpty ?? false)
          {'role': 'system', 'content': request.systemInstruction!.trim()},
        for (final message in request.messages) _messageJson(message),
      ],
      'stream': true,
    });

    var responseStarted = false;
    try {
      final response = await _client
          .send(httpRequest)
          .timeout(connectionTimeout);
      responseStarted = true;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        final message = _errorMessage(body, response.statusCode);
        yield AiResponseFailed(
          error: OpenAiCompatibleHttpException(response.statusCode, message),
          message: message,
          code: 'http_${response.statusCode}',
          retryable: response.statusCode == 408 || response.statusCode >= 500,
        );
        return;
      }

      var completed = false;
      AiTokenUsage? usage;
      await for (final line in response.stream
          .timeout(responseIdleTimeout)
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final payload = trimmed.substring(5).trim();
        if (payload.isEmpty) continue;
        if (payload == '[DONE]') {
          if (!completed) yield AiResponseCompleted(usage: usage);
          return;
        }
        final decoded = jsonDecode(payload);
        if (decoded is! Map) continue;
        final error = decoded['error'];
        if (error is Map || error is String) {
          final message =
              error is Map
                  ? error['message']?.toString() ?? 'AI request failed.'
                  : error.toString();
          yield AiResponseFailed(
            error: error,
            message: message,
            code: error is Map ? error['code']?.toString() : null,
            retryable: true,
          );
          return;
        }
        usage = _usage(decoded['usage']) ?? usage;
        final choices = decoded['choices'];
        if (choices is! List || choices.isEmpty || choices.first is! Map) {
          continue;
        }
        final choice = choices.first as Map;
        final delta = choice['delta'];
        if (delta is Map) {
          final content = delta['content'];
          if (content is String && content.isNotEmpty) {
            yield AiTextDelta(content);
          }
        }
        final finishReason = choice['finish_reason']?.toString();
        if (finishReason != null && finishReason != 'null') {
          completed = true;
          yield AiResponseCompleted(finishReason: finishReason, usage: usage);
        }
      }
      if (!completed) yield AiResponseCompleted(usage: usage);
    } on http.RequestAbortedException catch (error) {
      yield AiResponseFailed(
        error: error,
        message: 'Response stopped.',
        code: 'cancelled',
        retryable: true,
      );
    } on TimeoutException catch (error) {
      yield AiResponseFailed(
        error: error,
        message:
            responseStarted
                ? 'The AI endpoint stopped sending response data.'
                : 'The AI endpoint did not start responding in time.',
        code: responseStarted ? 'stream_timeout' : 'connection_timeout',
        retryable: true,
      );
    } on FormatException catch (error) {
      yield AiResponseFailed(
        error: error,
        message: 'The AI endpoint returned a malformed streaming response.',
        code: 'invalid_response',
      );
    } catch (error) {
      yield AiResponseFailed(
        error: error,
        message: 'The AI response was interrupted: $error',
        retryable: true,
      );
    }
  }

  AiConnectionResult? _configurationError(AiConnectionProfile profile) {
    if (!profile.isValid) {
      return const AiConnectionResult(
        status: AiConnectionStatus.invalidConfiguration,
        message: 'The AI connection profile is incomplete.',
      );
    }
    if (profile.protocol != AiProtocol.openAiCompatibleChat) {
      return const AiConnectionResult(
        status: AiConnectionStatus.unsupported,
        message: 'This AI protocol is not implemented yet.',
      );
    }
    if (profile.authenticationMode != AiAuthenticationMode.none) {
      return const AiConnectionResult(
        status: AiConnectionStatus.unsupported,
        message: 'Direct endpoint credentials are not available yet.',
      );
    }
    return null;
  }

  static Map<String, Object?> _messageJson(AiChatMessage message) {
    final result = <String, Object?>{
      'role': message.role.name,
      'content': message.content,
    };
    if (message.toolCallId != null) result['tool_call_id'] = message.toolCallId;
    return result;
  }

  static AiTokenUsage? _usage(Object? value) {
    if (value is! Map) return null;
    final input = value['prompt_tokens'];
    final output = value['completion_tokens'];
    if (input is! num || output is! num) return null;
    return AiTokenUsage(
      inputTokens: input.toInt(),
      outputTokens: output.toInt(),
      totalTokens: (value['total_tokens'] as num?)?.toInt(),
    );
  }

  static Map<String, String> _headers(AiConnectionProfile _) => const {
    'accept': 'application/json, text/event-stream',
    'content-type': 'application/json',
  };

  static Uri _endpoint(Uri baseUrl, String relativePath) {
    final path = baseUrl.path.endsWith('/') ? baseUrl.path : '${baseUrl.path}/';
    return baseUrl.replace(path: path).resolve(relativePath);
  }

  static String _errorMessage(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] != null) {
          return error['message'].toString();
        }
        if (error is String) return error;
        if (decoded['message'] != null) return decoded['message'].toString();
      }
    } catch (_) {}
    return 'The AI endpoint returned HTTP $statusCode.';
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

class OpenAiCompatibleHttpException implements Exception {
  const OpenAiCompatibleHttpException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'HTTP $statusCode: $message';
}
