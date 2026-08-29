import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  late AiConnectionProfile profile;

  setUp(() {
    profile = AiConnectionProfile(
      id: 'home',
      name: 'Home AI',
      protocol: AiProtocol.openAiCompatibleChat,
      baseUrl: Uri.parse('https://ai.example.test/v1'),
      modelId: 'model-a',
    );
  });

  test(
    'discovers models and reports the selected model as connected',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'https://ai.example.test/v1/models');
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'model-a', 'owned_by': 'local'},
              {'id': 'model-b'},
            ],
          }),
          200,
        );
      });
      final repository = OpenAiCompatibleAssistantRepository(client: client);

      final models = await repository.listModels(profile);
      final result = await repository.testConnection(profile);

      expect(models.map((model) => model.id), ['model-a', 'model-b']);
      expect(models.first.ownedBy, 'local');
      expect(result.status, AiConnectionStatus.connected);
    },
  );

  test('reports a missing selected model', () async {
    final repository = OpenAiCompatibleAssistantRepository(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': [
              {'id': 'another-model'},
            ],
          }),
          200,
        ),
      ),
    );

    final result = await repository.testConnection(profile);

    expect(result.status, AiConnectionStatus.modelNotFound);
  });

  test('explains that Ollama base URLs need the v1 path', () async {
    final repository = OpenAiCompatibleAssistantRepository(
      client: MockClient((_) async => http.Response('Not Found', 404)),
    );

    final result = await repository.testConnection(
      profile.copyWith(baseUrl: Uri.parse('http://localhost:11434')),
    );

    expect(result.status, AiConnectionStatus.invalidConfiguration);
    expect(result.message, contains('ending in /v1'));
  });

  test('normalizes streamed chat completion deltas', () async {
    late http.Request sentRequest;
    final repository = OpenAiCompatibleAssistantRepository(
      client: MockClient((request) async {
        sentRequest = request;
        return http.Response(
          [
            'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'reasoning_content': 'Checking '},
                  'finish_reason': null,
                },
              ],
            })}',
            '',
            'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'thinking': 'context'},
                  'finish_reason': null,
                },
              ],
            })}',
            '',
            'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': 'Hello '},
                  'finish_reason': null,
                },
              ],
            })}',
            '',
            'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': 'world'},
                  'finish_reason': null,
                },
              ],
            })}',
            '',
            'data: ${jsonEncode({
              'choices': [
                {'delta': {}, 'finish_reason': 'stop'},
              ],
            })}',
            '',
            'data: [DONE]',
            '',
          ].join('\n'),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      }),
    );
    final configuredProfile = profile.copyWith(
      reasoningEffort: AiReasoningEffort.none,
      maxOutputTokens: 512,
    );
    final handle = await repository.startResponse(
      AiChatRequest(
        connectionProfile: configuredProfile,
        conversationId: 'conversation-1',
        systemInstruction: 'Keep answers short.',
        messages: [
          AiChatMessage(
            id: 'message-1',
            role: AiMessageRole.user,
            content: 'Hi',
            createdAt: DateTime.utc(2026, 8, 29),
          ),
        ],
      ),
    );

    final events = await handle.events.toList();
    final requestBody = jsonDecode(sentRequest.body) as Map<String, dynamic>;

    expect(sentRequest.method, 'POST');
    expect(
      sentRequest.url.toString(),
      'https://ai.example.test/v1/chat/completions',
    );
    expect(requestBody['model'], 'model-a');
    expect(requestBody['stream'], isTrue);
    expect(requestBody['max_tokens'], 512);
    expect(requestBody['reasoning_effort'], 'none');
    final messages = requestBody['messages'] as List;
    expect(messages, hasLength(2));
    expect(messages.first, {
      'role': 'system',
      'content': 'Keep answers short.',
    });
    expect(messages.last['role'], 'user');
    expect(messages.last['content'], 'Hi');
    expect(
      events.whereType<AiReasoningDelta>().map((event) => event.text).join(),
      'Checking context',
    );
    expect(
      events.whereType<AiTextDelta>().map((event) => event.text).join(),
      'Hello world',
    );
    expect(events.whereType<AiResponseCompleted>(), hasLength(1));
  });

  test('accepts a non-streaming message from a compatible endpoint', () async {
    final repository = OpenAiCompatibleAssistantRepository(
      client: MockClient(
        (_) async => http.Response(
          'data: ${jsonEncode({
            'choices': [
              {
                'message': {'reasoning': 'Checked the request', 'content': 'A complete answer'},
                'finish_reason': 'stop',
              },
            ],
          })}\n\n',
          200,
          headers: {'content-type': 'text/event-stream'},
        ),
      ),
    );
    final handle = await repository.startResponse(_request(profile));

    final events = await handle.events.toList();

    expect(
      events.whereType<AiReasoningDelta>().single.text,
      'Checked the request',
    );
    expect(events.whereType<AiTextDelta>().single.text, 'A complete answer');
    expect(events.whereType<AiResponseCompleted>(), hasLength(1));
  });

  test('reports an empty compatible stream as a protocol problem', () async {
    final repository = OpenAiCompatibleAssistantRepository(
      client: MockClient(
        (_) async => http.Response(
          'data: [DONE]\n\n',
          200,
          headers: {'content-type': 'text/event-stream'},
        ),
      ),
    );
    final handle = await repository.startResponse(_request(profile));

    final event = (await handle.events.toList()).single as AiResponseFailed;

    expect(event.code, 'empty_response');
    expect(event.message, contains('OpenAI-compatible API format'));
    expect(event.retryable, isFalse);
  });

  test('turns a client connection failure into actionable guidance', () async {
    final repository = OpenAiCompatibleAssistantRepository(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    final handle = await repository.startResponse(_request(profile));

    final event = (await handle.events.toList()).single as AiResponseFailed;

    expect(event.code, 'unreachable');
    expect(event.message, contains('server is running'));
    expect(event.retryable, isTrue);
    expect(event.message, isNot(contains('offline')));
  });

  test('normalizes an HTTP failure into a retryable stream failure', () async {
    final repository = OpenAiCompatibleAssistantRepository(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'message': 'Model is warming up'},
          }),
          503,
        ),
      ),
    );
    final handle = await repository.startResponse(
      AiChatRequest(
        connectionProfile: profile,
        conversationId: 'conversation-1',
        messages: const [],
      ),
    );

    final event = (await handle.events.toList()).single as AiResponseFailed;

    expect(event.message, 'Model is warming up');
    expect(event.code, 'http_503');
    expect(event.retryable, isTrue);
  });

  test('omits reasoning effort when the profile uses automatic', () async {
    late http.Request sentRequest;
    final repository = OpenAiCompatibleAssistantRepository(
      client: MockClient((request) async {
        sentRequest = request;
        return http.Response(
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': 'Ready'},
                'finish_reason': 'stop',
              },
            ],
          })}\n\n',
          200,
        );
      }),
    );
    final handle = await repository.startResponse(_request(profile));

    await handle.events.toList();
    final requestBody = jsonDecode(sentRequest.body) as Map<String, dynamic>;

    expect(requestBody, isNot(contains('reasoning_effort')));
    expect(requestBody['max_tokens'], aiDefaultMaxOutputTokens);
  });

  test(
    'uses the profile connection timeout while starting a response',
    () async {
      final repository = OpenAiCompatibleAssistantRepository(
        client: _StreamedResponseClient(
          (_) => Completer<http.StreamedResponse>().future,
        ),
      );
      final handle = await repository.startResponse(
        _request(
          profile.copyWith(connectionTimeout: const Duration(milliseconds: 10)),
        ),
      );

      final event = (await handle.events.toList()).single as AiResponseFailed;

      expect(event.code, 'connection_timeout');
      expect(event.message, contains('did not start'));
    },
  );

  test('normalizes a plain-string streamed Ollama error', () async {
    final repository = OpenAiCompatibleAssistantRepository(
      client: MockClient(
        (_) async => http.Response(
          'data: ${jsonEncode({'error': 'model runner stopped'})}\n\n',
          200,
          headers: {'content-type': 'text/event-stream'},
        ),
      ),
    );
    final handle = await repository.startResponse(_request(profile));

    final event = (await handle.events.toList()).single as AiResponseFailed;

    expect(event.message, 'model runner stopped');
    expect(event.retryable, isTrue);
  });

  test('fails a response that stops producing stream data', () async {
    final streamController = StreamController<List<int>>();
    addTearDown(streamController.close);
    final repository = OpenAiCompatibleAssistantRepository(
      client: _StreamedResponseClient(
        (_) async => http.StreamedResponse(streamController.stream, 200),
      ),
    );
    final handle = await repository.startResponse(
      _request(
        profile.copyWith(responseIdleTimeout: const Duration(milliseconds: 10)),
      ),
    );

    final event = (await handle.events.toList()).single as AiResponseFailed;

    expect(event.code, 'stream_timeout');
    expect(event.message, contains('stopped sending'));
    expect(event.retryable, isTrue);
  });

  test(
    'reports malformed streamed JSON without exposing parser details',
    () async {
      final repository = OpenAiCompatibleAssistantRepository(
        client: MockClient(
          (_) async => http.Response(
            'data: {not-json}\n\n',
            200,
            headers: {'content-type': 'text/event-stream'},
          ),
        ),
      );
      final handle = await repository.startResponse(_request(profile));

      final event = (await handle.events.toList()).single as AiResponseFailed;

      expect(event.code, 'invalid_response');
      expect(event.message, contains('malformed'));
      expect(event.retryable, isFalse);
    },
  );

  test(
    'rejects protocols that do not use compatible chat completions',
    () async {
      final repository = OpenAiCompatibleAssistantRepository(
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      final unsupported = profile.copyWith(
        protocol: AiProtocol.anthropicMessages,
      );

      final result = await repository.testConnection(unsupported);

      expect(result.status, AiConnectionStatus.unsupported);
    },
  );
}

AiChatRequest _request(AiConnectionProfile profile) => AiChatRequest(
  connectionProfile: profile,
  conversationId: 'conversation-1',
  messages: const [],
);

class _StreamedResponseClient extends http.BaseClient {
  _StreamedResponseClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _handler(request);
}
