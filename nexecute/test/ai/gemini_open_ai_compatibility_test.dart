import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexecute/ai/ai.dart';

import '../../tool/ai_quality_evaluation.dart';

void main() {
  test(
    'uses the trusted Gemini endpoint, bearer key, and client header',
    () async {
      final requests = <http.Request>[];
      final repository = OpenAiCompatibleAssistantRepository(
        credentialStore: const _CredentialStore(),
        client: MockClient((request) async {
          requests.add(request);
          expect(request.headers['authorization'], 'Bearer gemini-test-key');
          expect(request.headers['x-goog-api-client'], nexecuteGeminiApiClient);
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'data': [
                  {'id': 'gemini-test-model', 'owned_by': 'google'},
                ],
              }),
              200,
            );
          }
          return _streamResponse('Terve!');
        }),
      );
      addTearDown(repository.dispose);

      final models = await repository.listModels(_profile());
      final connection = await repository.testConnection(_profile());
      final handle = await repository.startResponse(_request());
      final events = await handle.events.toList();

      expect(models.single.id, 'gemini-test-model');
      expect(connection.status, AiConnectionStatus.connected);
      expect(requests.map((request) => request.url.toString()), [
        'https://generativelanguage.googleapis.com/v1beta/openai/models',
        'https://generativelanguage.googleapis.com/v1beta/openai/models',
        'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
      ]);
      expect(events.whereType<AiTextDelta>().single.text, 'Terve!');
      expect(events.last, isA<AiResponseCompleted>());
      expect(_profile().supports(AiCapability.streaming), isTrue);
      expect(_profile().supports(AiCapability.modelDiscovery), isTrue);
      expect(_profile().supports(AiCapability.tools), isFalse);
      expect(_profile().supports(AiCapability.structuredOutput), isFalse);
    },
  );

  test(
    'normalizes Gemini tool calls and serializes their continuation',
    () async {
      final bodies = <Map<String, dynamic>>[];
      var requestIndex = 0;
      final repository = OpenAiCompatibleAssistantRepository(
        credentialStore: const _CredentialStore(),
        client: MockClient((request) async {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          if (requestIndex++ == 0) {
            return http.Response(
              [
                'data: ${jsonEncode({
                  'choices': [
                    {
                      'delta': {
                        'tool_calls': [
                          {
                            'index': 0,
                            'id': 'gemini-call-1',
                            'type': 'function',
                            'function': {'name': AiReadToolNames.listTasks, 'arguments': '{"limit":5}'},
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
            );
          }
          return _streamResponse('Sinulla ei ole avoimia tehtäviä.');
        }),
      );
      addTearDown(repository.dispose);
      final toolProfile = _profile().copyWith(
        capabilityOverrides: const {AiCapability.tools: true},
      );
      final authorization = AiReadToolAuthorization(allowActiveTasks: true);
      final firstHandle = await repository.startResponse(
        _request(profile: toolProfile, authorization: authorization),
      );
      final firstEvents = await firstHandle.events.toList();
      final call = firstEvents.whereType<AiToolCallRequested>().single.call;

      final secondHandle = await repository.startResponse(
        _request(
          profile: toolProfile,
          authorization: authorization,
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
      final secondEvents = await secondHandle.events.toList();

      expect(call.name, AiReadToolNames.listTasks);
      expect(call.arguments, {'limit': 5});
      expect(bodies.first['tools'], isNotEmpty);
      final messages = bodies.last['messages'] as List<dynamic>;
      expect(messages[messages.length - 2]['role'], 'assistant');
      expect(messages.last['role'], 'tool');
      expect(messages.last['tool_call_id'], call.id);
      final secondFailure =
          secondEvents.whereType<AiResponseFailed>().firstOrNull;
      expect(
        secondFailure,
        isNull,
        reason:
            '${secondFailure?.code}: ${secondFailure?.message}; '
            '${secondFailure?.error}',
      );
      expect(
        secondEvents.whereType<AiTextDelta>().single.text,
        'Sinulla ei ole avoimia tehtäviä.',
      );
    },
  );

  test('cancels an in-flight Gemini request', () async {
    final requestStarted = Completer<void>();
    final repository = OpenAiCompatibleAssistantRepository(
      credentialStore: const _CredentialStore(),
      client: _AbortClient((request) async {
        requestStarted.complete();
        await (request as http.AbortableRequest).abortTrigger;
        throw http.RequestAbortedException(request.url);
      }),
    );
    addTearDown(repository.dispose);
    final handle = await repository.startResponse(_request());
    final eventsFuture = handle.events.toList();

    await requestStarted.future;
    await handle.cancel();
    final events = await eventsFuture;

    expect(events.single, isA<AiResponseFailed>());
    expect((events.single as AiResponseFailed).code, 'cancelled');
  });

  test(
    'redacts Gemini authentication, rate-limit, and malformed errors',
    () async {
      const privateDetail = 'gemini-test-key private prompt';
      final responses = <http.Response>[
        http.Response(
          jsonEncode({
            'error': {'message': privateDetail},
          }),
          401,
        ),
        http.Response(
          jsonEncode({
            'error': {'message': privateDetail},
          }),
          429,
        ),
        http.Response(
          'data: {malformed-$privateDetail}\n\n',
          200,
          headers: {'content-type': 'text/event-stream'},
        ),
      ];
      final repository = OpenAiCompatibleAssistantRepository(
        credentialStore: const _CredentialStore(),
        client: MockClient((_) async => responses.removeAt(0)),
      );
      addTearDown(repository.dispose);

      final authentication = await repository.testConnection(_profile());
      final rateLimitHandle = await repository.startResponse(_request());
      final rateLimit =
          (await rateLimitHandle.events.toList()).single as AiResponseFailed;
      final malformedHandle = await repository.startResponse(_request());
      final malformed =
          (await malformedHandle.events.toList()).single as AiResponseFailed;

      expect(authentication.status, AiConnectionStatus.authenticationFailed);
      expect(authentication.diagnostic?.kind, AiDiagnosticKind.authentication);
      expect(rateLimit.code, 'http_429');
      expect(rateLimit.retryable, isTrue);
      expect(rateLimit.diagnostic?.kind, AiDiagnosticKind.rateLimited);
      expect(malformed.code, 'invalid_response');
      final visibleOutput = [
        authentication.message,
        rateLimit.message,
        rateLimit.error,
        malformed.message,
        malformed.error,
      ].join(' ');
      expect(visibleOutput, isNot(contains(privateDetail)));
      expect(visibleOutput, isNot(contains('gemini-test-key')));
    },
  );

  test(
    'runs Finnish chat and structured workflows through the quality evaluator',
    () async {
      final responses = <http.Response>[
        _streamResponse('7'),
        _streamResponse(
          '{"schemaVersion":1,"tasks":[{"title":"Osta kauramaitoa"}]}',
        ),
        _streamResponse(
          '{"schemaVersion":1,"event":{"title":"Hammaslääkäri",'
          '"description":"","startDate":"2026-08-31",'
          '"startTime":"14:00","endDate":"2026-08-31",'
          '"endTime":"15:00","isAllDay":false}}',
        ),
      ];
      final seenHeaders = <String?>[];
      final repository = OpenAiCompatibleAssistantRepository(
        credentialStore: const _CredentialStore(),
        client: MockClient((request) async {
          seenHeaders.add(request.headers['x-goog-api-client']);
          return responses.removeAt(0);
        }),
      );
      addTearDown(repository.dispose);
      final suite = AiQualitySuite.fromJsonString(
        jsonEncode({
          'schemaVersion': 1,
          'suiteVersion': 'gemini-wire-test',
          'description': 'Gemini compatibility workflows',
          'cases': [
            {
              'id': 'chat-fi',
              'workflow': 'chat',
              'language': 'fi',
              'coverage': ['simple'],
              'input': {'message': 'Paljonko on 3 + 4?'},
              'expectation': {
                'exact': '7',
                'requiredAny': <Object?>[],
                'forbiddenAny': <Object?>[],
              },
            },
            {
              'id': 'tasks-fi',
              'workflow': 'noteToTasks',
              'language': 'fi',
              'coverage': ['simple'],
              'input': {
                'noteTitle': 'Kauppa',
                'noteContent': 'Osta kauramaitoa.',
              },
              'expectation': {
                'minTasks': 1,
                'maxTasks': 1,
                'requiredAny': [
                  ['kauramaitoa'],
                ],
                'forbiddenAny': <Object?>[],
              },
            },
            {
              'id': 'event-fi',
              'workflow': 'noteToEvent',
              'language': 'fi',
              'coverage': ['dates', 'relativeDate', 'localTime'],
              'input': {
                'noteTitle': 'Ajanvaraus',
                'noteContent': 'Hammaslääkäri huomenna klo 14–15.',
                'referenceLocalDateTime': '2026-08-30T17:45:00',
                'utcOffsetMinutes': 180,
              },
              'expectation': {
                'expectedEvent': true,
                'startDate': '2026-08-31',
                'startTime': '14:00',
                'endDate': '2026-08-31',
                'endTime': '15:00',
                'isAllDay': false,
                'hasCompleteSchedule': true,
                'requiredAny': [
                  ['hammaslääkäri'],
                ],
                'forbiddenAny': <Object?>[],
              },
            },
          ],
        }),
      );

      final report = await AiQualityEvaluator(repository: repository).run(
        suite: suite,
        profile: _profile(),
        metadata: const AiQualityRunMetadata(
          modelId: 'gemini-test-model',
          modelVersion: 'deterministic-fixture',
          repetitions: 1,
        ),
      );

      expect(report.passed, isTrue, reason: jsonEncode(report.toJson()));
      expect(
        report.results.map((result) => result.outcome),
        everyElement(AiQualityOutcome.passed),
      );
      expect(seenHeaders, everyElement(nexecuteGeminiApiClient));
      final reportJson = jsonEncode(report.toJson());
      expect(reportJson, isNot(contains('generativelanguage.googleapis.com')));
      expect(reportJson, isNot(contains('gemini-test-key')));
    },
  );
}

AiConnectionProfile _profile() {
  final provider = AiProviderCatalog.googleGemini;
  return AiConnectionProfile(
    id: 'gemini',
    name: 'Gemini',
    providerKind: provider.kind,
    protocol: provider.protocol,
    baseUrl: provider.trustedBaseUri!,
    modelId: 'gemini-test-model',
    hostedInferenceEnabled: true,
    authenticationMode: provider.authenticationMode,
    credentialReference: _CredentialStore.reference,
  );
}

AiChatRequest _request({
  AiConnectionProfile? profile,
  AiReadToolAuthorization? authorization,
  List<AiToolContinuationMessage> continuationMessages = const [],
}) => AiChatRequest(
  connectionProfile: profile ?? _profile(),
  conversationId: 'gemini-test',
  systemInstruction: 'Reply in the same language as the user.',
  messages: [
    AiChatMessage(
      id: 'message',
      role: AiMessageRole.user,
      content: 'Hei',
      createdAt: DateTime.utc(2026, 9, 6),
    ),
  ],
  readToolAuthorization: authorization,
  continuationMessages: continuationMessages,
);

http.Response _streamResponse(String text) => http.Response(
  'data: ${jsonEncode({
    'choices': [
      {
        'delta': {'content': text},
        'finish_reason': 'stop',
      },
    ],
  })}\n\ndata: [DONE]\n\n',
  200,
  headers: {'content-type': 'text/event-stream; charset=utf-8'},
);

final class _CredentialStore implements AiCredentialStore {
  const _CredentialStore();

  static const reference = 'secure-storage:gemini-test';

  @override
  bool get isAvailable => true;

  @override
  Future<void> deleteCredential(String reference) => throw UnimplementedError();

  @override
  Future<String?> readCredential(String reference) async =>
      reference == _CredentialStore.reference ? 'gemini-test-key' : null;

  @override
  Future<String> saveCredential(String credential) =>
      throw UnimplementedError();
}

final class _AbortClient extends http.BaseClient {
  _AbortClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}
