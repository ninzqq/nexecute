import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

import '../../tool/ai_quality_evaluation.dart';

void main() {
  group('committed AI quality suite', () {
    late AiQualitySuite suite;

    setUpAll(() {
      // Tests run from the package root under flutter test.
      suite = AiQualitySuite.fromJsonString(
        File('evaluation/ai_quality_cases.v1.json').readAsStringSync(),
      );
    });

    test('is bilingual across chat, attached context, and note extraction', () {
      for (final workflow in const [
        AiQualityWorkflow.chat,
        AiQualityWorkflow.attachedContext,
        AiQualityWorkflow.noteToTasks,
      ]) {
        final languages =
            suite.cases
                .where((evaluationCase) => evaluationCase.workflow == workflow)
                .map((evaluationCase) => evaluationCase.language)
                .toSet();
        expect(languages, {'en', 'fi'});
      }
    });

    test('covers every roadmap quality risk', () {
      final coverage = suite.cases.expand((value) => value.coverage).toSet();
      expect(
        coverage,
        containsAll({
          'simple',
          'multipleTasks',
          'dates',
          'ambiguity',
          'missingInformation',
          'promptInjection',
          'hallucinations',
          'malformedStructuredData',
          'attachedContext',
          'explicitScope',
          'malformedToolCall',
          'excessiveToolCalls',
          'unknownToolCall',
          'unauthorizedToolCall',
        }),
      );
    });

    test('keeps all source inputs synthetic and endpoint-free', () {
      for (final evaluationCase in suite.cases) {
        final source = jsonEncode(evaluationCase.input).toLowerCase();
        expect(source, isNot(contains('http://')));
        expect(source, isNot(contains('https://')));
        expect(source, isNot(contains('@')));
      }
    });
  });

  test(
    'separates transport, application, and model-quality failures',
    () async {
      final suite = AiQualitySuite.fromJsonString(
        jsonEncode({
          'schemaVersion': 1,
          'suiteVersion': 'test',
          'description': 'Taxonomy contract',
          'cases': [
            _chatCase('transport', exact: 'ok'),
            _taskCase('application'),
            _chatCase('quality', exact: 'expected'),
            _taskCase('passed'),
          ],
        }),
      );
      final repository = _QueuedRepository([
        [
          AiResponseFailed(
            error: Exception('offline'),
            message: 'Endpoint unavailable.',
            code: 'unreachable',
          ),
        ],
        const [AiTextDelta('not json'), AiResponseCompleted()],
        const [AiTextDelta('wrong'), AiResponseCompleted()],
        const [
          AiTextDelta('{"schemaVersion":1,"tasks":[{"title":"Buy oat milk"}]}'),
          AiResponseCompleted(),
        ],
      ]);
      final evaluator = AiQualityEvaluator(
        repository: repository,
        clock: () => DateTime.utc(2026, 8, 29),
      );

      final report = await evaluator.run(
        suite: suite,
        profile: _profile(),
        metadata: const AiQualityRunMetadata(
          modelId: 'model-a',
          modelVersion: 'sha256:test',
          repetitions: 1,
        ),
      );

      expect(report.results.map((result) => result.outcome), [
        AiQualityOutcome.transportFailure,
        AiQualityOutcome.applicationFailure,
        AiQualityOutcome.qualityFailure,
        AiQualityOutcome.passed,
      ]);
      final json = report.toJson();
      expect((json['run'] as Map)['model'], {
        'id': 'model-a',
        'version': 'sha256:test',
      });
      expect((json['summary'] as Map)['transportFailure'], 1);
      expect((json['summary'] as Map)['applicationFailure'], 1);
      expect((json['summary'] as Map)['qualityFailure'], 1);
      expect((json['summary'] as Map)['passed'], 1);
      expect(jsonEncode(json), isNot(contains('ai.example.test')));
    },
  );

  test(
    'malformed fixtures exercise parser guardrails without a request',
    () async {
      final suite = AiQualitySuite.fromJsonString(
        jsonEncode({
          'schemaVersion': 1,
          'suiteVersion': 'test',
          'description': 'Parser fixture contract',
          'cases': [
            {
              'id': 'fixture',
              'workflow': 'parserFixture',
              'language': 'en',
              'coverage': ['malformedStructuredData'],
              'input': {'response': 'Here: {"schemaVersion":1,"tasks":[]}'},
              'expectation': {'parserErrorCode': 'invalidJson'},
            },
          ],
        }),
      );
      final repository = _QueuedRepository(const []);

      final report = await AiQualityEvaluator(repository: repository).run(
        suite: suite,
        profile: _profile(),
        metadata: const AiQualityRunMetadata(
          modelId: 'model-a',
          modelVersion: 'v1',
          repetitions: 1,
        ),
      );

      expect(report.results.single.outcome, AiQualityOutcome.passed);
      expect(repository.requestCount, 0);
    },
  );

  test(
    'attached-context workflow sends the canonical bounded envelope',
    () async {
      final suite = AiQualitySuite.fromJsonString(
        jsonEncode({
          'schemaVersion': 1,
          'suiteVersion': 'test',
          'description': 'Attached context contract',
          'cases': [
            {
              'id': 'attached',
              'workflow': 'attachedContext',
              'language': 'en',
              'coverage': ['attachedContext'],
              'input': {
                'message': 'Which task?',
                'applicationContext': {
                  'generatedAt': '2026-08-30T09:00:00.000Z',
                  'tasks': [
                    {'title': 'Review 9F', 'isCompleted': false},
                  ],
                  'omittedCount': 2,
                  'payloadTruncated': false,
                },
              },
              'expectation': {
                'requiredAny': [
                  ['review'],
                ],
                'forbiddenAny': <String>[],
              },
            },
          ],
        }),
      );
      final repository = _QueuedRepository(const [
        [AiTextDelta('Review 9F'), AiResponseCompleted()],
      ]);

      final report = await AiQualityEvaluator(repository: repository).run(
        suite: suite,
        profile: _profile(),
        metadata: const AiQualityRunMetadata(
          modelId: 'model-a',
          modelVersion: 'v1',
          repetitions: 1,
        ),
      );

      expect(report.results.single.outcome, AiQualityOutcome.passed);
      final context = repository.requests.single.applicationContext!;
      expect(context.serializedCharacterCount, lessThanOrEqualTo(24000));
      expect(context.encode(), contains('Review 9F'));
      expect(context.encode(), contains('"omittedCount":2'));
    },
  );

  test(
    'committed tool fixtures exercise production guardrails without endpoint requests',
    () async {
      final suite = AiQualitySuite.fromJsonString(
        File('evaluation/ai_quality_cases.v1.json').readAsStringSync(),
      );
      final repository = _QueuedRepository(const []);
      final ids = {
        for (final evaluationCase in suite.cases)
          if (evaluationCase.workflow == AiQualityWorkflow.toolProtocolFixture)
            evaluationCase.id,
      };

      final report = await AiQualityEvaluator(repository: repository).run(
        suite: suite,
        profile: _profile(),
        metadata: const AiQualityRunMetadata(
          modelId: 'model-a',
          modelVersion: 'v1',
          repetitions: 1,
        ),
        caseIds: ids,
      );

      expect(ids, hasLength(4));
      expect(
        report.results.map((result) => result.outcome),
        everyElement(AiQualityOutcome.passed),
      );
      expect(repository.requestCount, 0);
    },
  );
}

Map<String, Object?> _chatCase(String id, {required String exact}) => {
  'id': id,
  'workflow': 'chat',
  'language': 'en',
  'coverage': ['simple'],
  'input': {'message': 'Reply.'},
  'expectation': {'exact': exact, 'requiredAny': [], 'forbiddenAny': []},
};

Map<String, Object?> _taskCase(String id) => {
  'id': id,
  'workflow': 'noteToTasks',
  'language': 'en',
  'coverage': ['simple'],
  'input': {'noteTitle': 'Groceries', 'noteContent': 'Buy oat milk.'},
  'expectation': {
    'minTasks': 1,
    'maxTasks': 1,
    'requiredAny': [
      ['oat milk'],
    ],
    'forbiddenAny': [],
  },
};

AiConnectionProfile _profile() => AiConnectionProfile(
  id: 'test',
  name: 'Test',
  protocol: AiProtocol.openAiCompatibleChat,
  baseUrl: Uri.parse('https://ai.example.test/v1'),
  modelId: 'model-a',
);

class _QueuedRepository implements AiAssistantRepository {
  _QueuedRepository(this.responses);

  final List<List<AiStreamEvent>> responses;
  final List<AiChatRequest> requests = [];
  var requestCount = 0;

  @override
  Future<AiResponseHandle> startResponse(AiChatRequest request) async {
    requests.add(request);
    final response = responses[requestCount++];
    return StreamAiResponseHandle(
      events: Stream.fromIterable(response),
      onCancel: () async {},
    );
  }

  @override
  Future<List<AiModelInfo>> listModels(AiConnectionProfile profile) async =>
      const [];

  @override
  Future<AiConnectionResult> testConnection(
    AiConnectionProfile profile,
  ) async => const AiConnectionResult(
    status: AiConnectionStatus.connected,
    message: 'Connected.',
  );
}
