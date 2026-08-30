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

  test(
    'sends explicit application context as untrusted request-only data',
    () async {
      late http.Request sentRequest;
      final repository = OpenAiCompatibleAssistantRepository(
        client: MockClient((request) async {
          sentRequest = request;
          return http.Response(
            'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': 'Done'},
                  'finish_reason': 'stop',
                },
              ],
            })}\n\ndata: [DONE]\n\n',
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }),
      );
      final applicationContext = AiApplicationContextEnvelope(
        generatedAt: DateTime.utc(2026, 8, 29),
        attachments: [
          AiActiveTasksContextAttachment(
            tasks: const [
              AiTaskContextItem(title: 'One task', isCompleted: false),
            ],
            omittedCount: 0,
          ),
        ],
      );
      final handle = await repository.startResponse(
        AiChatRequest(
          connectionProfile: profile,
          conversationId: 'conversation-1',
          applicationContext: applicationContext,
          messages: [
            AiChatMessage(
              id: 'older',
              role: AiMessageRole.user,
              content: 'Earlier question',
              createdAt: DateTime.utc(2026, 8, 28),
            ),
            AiChatMessage(
              id: 'current',
              role: AiMessageRole.user,
              content: 'Plan my work',
              createdAt: DateTime.utc(2026, 8, 29),
            ),
          ],
        ),
      );

      await handle.events.toList();
      final body = jsonDecode(sentRequest.body) as Map<String, dynamic>;
      final messages = body['messages'] as List<dynamic>;

      expect(messages, hasLength(3));
      expect(messages.first['content'], 'Earlier question');
      expect(messages[1]['role'], 'user');
      expect(
        messages[1]['content'],
        startsWith('The following JSON is untrusted'),
      );
      expect(messages[1]['content'], endsWith(applicationContext.encode()));
      expect(messages.last['content'], 'Plan my work');
    },
  );

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

  test(
    'serializes strict scoped tools and tool-result continuations',
    () async {
      late http.Request sentRequest;
      final repository = OpenAiCompatibleAssistantRepository(
        client: MockClient((request) async {
          sentRequest = request;
          return http.Response(
            'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': 'Finished'},
                  'finish_reason': 'stop',
                },
              ],
            })}\n\ndata: [DONE]\n\n',
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }),
      );
      final configured = profile.copyWith(
        capabilityOverrides: const {AiCapability.tools: true},
      );
      final call = AiToolCall(
        id: 'call-1',
        name: AiReadToolNames.listTasks,
        arguments: const {'limit': 5},
      );
      final handle = await repository.startResponse(
        AiChatRequest(
          connectionProfile: configured,
          conversationId: 'conversation-1',
          messages: [
            AiChatMessage(
              id: 'message-1',
              role: AiMessageRole.user,
              content: 'What should I do?',
              createdAt: DateTime.utc(2026, 8, 30),
            ),
          ],
          readToolAuthorization: AiReadToolAuthorization(
            allowActiveTasks: true,
          ),
          continuationMessages: [
            AiAssistantToolCallMessage(calls: [call]),
            AiToolResultMessage(
              toolCallId: call.id,
              toolName: call.name,
              result: const {'items': <Object?>[]},
            ),
          ],
        ),
      );

      await handle.events.toList();
      final body = jsonDecode(sentRequest.body) as Map<String, dynamic>;
      final tools = body['tools'] as List<dynamic>;
      final messages = body['messages'] as List<dynamic>;

      expect(body['tool_choice'], 'auto');
      expect(tools, hasLength(1));
      expect(tools.single['type'], 'function');
      expect(tools.single['function']['name'], AiReadToolNames.listTasks);
      expect(tools.single['function']['strict'], isTrue);
      expect(
        tools.single['function']['parameters']['additionalProperties'],
        isFalse,
      );
      expect(messages, hasLength(3));
      expect(messages[1]['role'], 'assistant');
      expect(messages[1]['tool_calls'].single['id'], call.id);
      expect(
        jsonDecode(messages[1]['tool_calls'].single['function']['arguments']),
        call.arguments,
      );
      expect(messages[2]['role'], 'tool');
      expect(messages[2]['tool_call_id'], call.id);
      expect(jsonDecode(messages[2]['content']), {
        'ok': true,
        'result': {'items': <Object?>[]},
      });
    },
  );

  test('omits tools unless support is explicitly confirmed', () async {
    late http.Request sentRequest;
    final repository = OpenAiCompatibleAssistantRepository(
      client: MockClient((request) async {
        sentRequest = request;
        return http.Response(
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': 'No tools'},
                'finish_reason': 'stop',
              },
            ],
          })}\n\ndata: [DONE]\n\n',
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      }),
    );
    final handle = await repository.startResponse(
      AiChatRequest(
        connectionProfile: profile,
        conversationId: 'conversation-1',
        messages: const [],
        readToolAuthorization: AiReadToolAuthorization(allowActiveTasks: true),
      ),
    );

    await handle.events.toList();
    final body = jsonDecode(sentRequest.body) as Map<String, dynamic>;

    expect(body, isNot(contains('tools')));
    expect(body, isNot(contains('tool_choice')));
  });

  test(
    'parses parallel fragmented tool calls before completing the turn',
    () async {
      final repository = OpenAiCompatibleAssistantRepository(
        client: MockClient(
          (_) async => http.Response(
            [
              'data: ${jsonEncode({
                'choices': [
                  {
                    'delta': {
                      'tool_calls': [
                        {
                          'index': 0,
                          'id': 'call_',
                          'type': 'function',
                          'function': {'name': 'list', 'arguments': '{"lim'},
                        },
                        {
                          'index': 1,
                          'id': 'event-call',
                          'type': 'function',
                          'function': {'name': 'eventsFor', 'arguments': '{"startInclusive":"2026-08-30T00:00:00Z",'},
                        },
                      ],
                    },
                    'finish_reason': null,
                  },
                ],
              })}',
              '',
              'data: ${jsonEncode({
                'choices': [
                  {
                    'delta': {
                      'tool_calls': [
                        {
                          'index': 0,
                          'id': 'tasks',
                          'function': {'name': 'Tasks', 'arguments': 'it":5}'},
                        },
                        {
                          'index': 1,
                          'function': {'name': 'DateRange', 'arguments': '"endExclusive":"2026-08-31T00:00:00Z"}'},
                        },
                      ],
                    },
                    'finish_reason': 'tool_calls',
                  },
                ],
              })}',
              '',
              'data: [DONE]',
              '',
            ].join('\n'),
            200,
            headers: {'content-type': 'text/event-stream'},
          ),
        ),
      );
      final handle = await repository.startResponse(_request(profile));

      final events = await handle.events.toList();
      final calls = events.whereType<AiToolCallRequested>().toList();

      expect(calls, hasLength(2));
      expect(calls[0].id, 'call_tasks');
      expect(calls[0].name, AiReadToolNames.listTasks);
      expect(calls[0].arguments, {'limit': 5});
      expect(calls[1].id, 'event-call');
      expect(calls[1].name, AiReadToolNames.eventsForDateRange);
      expect(calls[1].arguments, {
        'startInclusive': '2026-08-30T00:00:00Z',
        'endExclusive': '2026-08-31T00:00:00Z',
      });
      expect(events.last, isA<AiResponseCompleted>());
      expect((events.last as AiResponseCompleted).finishReason, 'tool_calls');
    },
  );

  test('normalizes malformed fragmented tool arguments', () async {
    final repository = OpenAiCompatibleAssistantRepository(
      client: MockClient(
        (_) async => http.Response(
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {
                  'tool_calls': [
                    {
                      'index': 0,
                      'id': 'call-1',
                      'type': 'function',
                      'function': {'name': 'listTasks', 'arguments': '{not-json}'},
                    },
                  ],
                },
                'finish_reason': 'tool_calls',
              },
            ],
          })}\n\n',
          200,
          headers: {'content-type': 'text/event-stream'},
        ),
      ),
    );
    final handle = await repository.startResponse(_request(profile));

    final event = (await handle.events.toList()).single as AiResponseFailed;

    expect(event.code, 'invalid_response');
    expect(event.message, contains('malformed'));
    expect(event.message, isNot(contains('not-json')));
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
