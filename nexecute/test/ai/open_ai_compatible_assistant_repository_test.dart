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
    final handle = await repository.startResponse(
      AiChatRequest(
        connectionProfile: profile,
        conversationId: 'conversation-1',
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
    expect((requestBody['messages'] as List).single['content'], 'Hi');
    expect(
      events.whereType<AiTextDelta>().map((event) => event.text).join(),
      'Hello world',
    );
    expect(events.whereType<AiResponseCompleted>(), hasLength(1));
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
