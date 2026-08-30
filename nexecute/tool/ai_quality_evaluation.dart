import 'dart:async';
import 'dart:convert';

import 'package:nexecute/ai/application/ai_application_context_read_contract.dart';
import 'package:nexecute/ai/application/ai_note_task_prompt.dart';
import 'package:nexecute/ai/application/ai_read_tool_coordinator.dart';
import 'package:nexecute/ai/domain/ai_application_context.dart';
import 'package:nexecute/ai/domain/ai_chat_message.dart';
import 'package:nexecute/ai/domain/ai_chat_request.dart';
import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/ai/domain/ai_connection_result.dart';
import 'package:nexecute/ai/domain/ai_model_info.dart';
import 'package:nexecute/ai/domain/ai_protocol.dart';
import 'package:nexecute/ai/domain/ai_stream_event.dart';
import 'package:nexecute/ai/domain/ai_task_proposal.dart';
import 'package:nexecute/ai/domain/ai_tool.dart';
import 'package:nexecute/ai/infrastructure/ai_task_proposal_parser.dart';
import 'package:nexecute/ai/repositories/ai_assistant_repository.dart';
import 'package:nexecute/ai/repositories/ai_response_handle.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';

enum AiQualityWorkflow {
  chat,
  attachedContext,
  noteToTasks,
  parserFixture,
  toolProtocolFixture,
}

enum AiQualityOutcome {
  passed,
  transportFailure,
  applicationFailure,
  qualityFailure,
}

class AiQualitySuite {
  AiQualitySuite({
    required this.schemaVersion,
    required this.suiteVersion,
    required this.description,
    required List<AiQualityCase> cases,
  }) : cases = List.unmodifiable(cases);

  factory AiQualitySuite.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    final root = _object(
      decoded,
      'The evaluation suite must be a JSON object.',
    );
    final schemaVersion = _integer(root, 'schemaVersion');
    if (schemaVersion != 1) {
      throw FormatException(
        'Unsupported evaluation schemaVersion: $schemaVersion.',
      );
    }
    final rawCases = root['cases'];
    if (rawCases is! List || rawCases.isEmpty) {
      throw const FormatException('The evaluation suite needs cases.');
    }
    final cases = [for (final value in rawCases) AiQualityCase.fromJson(value)];
    final ids = <String>{};
    for (final evaluationCase in cases) {
      if (!ids.add(evaluationCase.id)) {
        throw FormatException(
          'Duplicate evaluation case id: ${evaluationCase.id}.',
        );
      }
    }
    return AiQualitySuite(
      schemaVersion: schemaVersion,
      suiteVersion: _nonEmptyString(root, 'suiteVersion'),
      description: _nonEmptyString(root, 'description'),
      cases: cases,
    );
  }

  final int schemaVersion;
  final String suiteVersion;
  final String description;
  final List<AiQualityCase> cases;
}

class AiQualityCase {
  AiQualityCase({
    required this.id,
    required this.workflow,
    required this.language,
    required List<String> coverage,
    required Map<String, Object?> input,
    required Map<String, Object?> expectation,
  }) : coverage = List.unmodifiable(coverage),
       input = Map.unmodifiable(input),
       expectation = Map.unmodifiable(expectation);

  factory AiQualityCase.fromJson(Object? value) {
    final json = _object(value, 'Every evaluation case must be an object.');
    final workflowName = _nonEmptyString(json, 'workflow');
    final workflow = AiQualityWorkflow.values.firstWhere(
      (value) => value.name == workflowName,
      orElse:
          () =>
              throw FormatException(
                'Unsupported evaluation workflow: $workflowName.',
              ),
    );
    final language = _nonEmptyString(json, 'language');
    if (language != 'en' && language != 'fi') {
      throw FormatException('Unsupported evaluation language: $language.');
    }
    final rawCoverage = json['coverage'];
    if (rawCoverage is! List || rawCoverage.isEmpty) {
      throw const FormatException(
        'Every evaluation case needs at least one coverage label.',
      );
    }
    final coverage =
        rawCoverage.map((value) {
          if (value is! String || value.trim().isEmpty) {
            throw const FormatException(
              'Coverage labels must be non-empty text.',
            );
          }
          return value;
        }).toList();
    final input = _object(json['input'], 'Case input must be an object.');
    final expectation = _object(
      json['expectation'],
      'Case expectation must be an object.',
    );
    _validateCase(workflow, input, expectation);
    return AiQualityCase(
      id: _nonEmptyString(json, 'id'),
      workflow: workflow,
      language: language,
      coverage: coverage,
      input: input,
      expectation: expectation,
    );
  }

  final String id;
  final AiQualityWorkflow workflow;
  final String language;
  final List<String> coverage;
  final Map<String, Object?> input;
  final Map<String, Object?> expectation;

  static void _validateCase(
    AiQualityWorkflow workflow,
    Map<String, Object?> input,
    Map<String, Object?> expectation,
  ) {
    switch (workflow) {
      case AiQualityWorkflow.chat:
        _nonEmptyString(input, 'message');
        _validateTextChecks(expectation);
      case AiQualityWorkflow.attachedContext:
        _nonEmptyString(input, 'message');
        _attachedContextFrom(input);
        _validateTextChecks(expectation);
      case AiQualityWorkflow.noteToTasks:
        _string(input, 'noteTitle');
        _string(input, 'noteContent');
        _integer(expectation, 'minTasks');
        _integer(expectation, 'maxTasks');
        if ((expectation['minTasks'] as int) < 0 ||
            (expectation['maxTasks'] as int) <
                (expectation['minTasks'] as int)) {
          throw const FormatException('Task-count bounds are invalid.');
        }
        _validateTextChecks(expectation);
      case AiQualityWorkflow.parserFixture:
        _nonEmptyString(input, 'response');
        final expectedCode = _nonEmptyString(expectation, 'parserErrorCode');
        if (!AiTaskProposalErrorCode.values.any(
          (value) => value.name == expectedCode,
        )) {
          throw FormatException(
            'Unsupported parser error code: $expectedCode.',
          );
        }
      case AiQualityWorkflow.toolProtocolFixture:
        _toolCallsFrom(input);
        final authorization = _object(
          input['authorization'],
          'Tool fixture authorization must be an object.',
        );
        final allowActiveTasks = authorization['allowActiveTasks'];
        if (allowActiveTasks is! bool) {
          throw const FormatException('allowActiveTasks must be a boolean.');
        }
        final expectedErrors = _strings(
          expectation['toolErrorCodes'],
          'toolErrorCodes',
        );
        final failureCode = expectation['failureCode'];
        if ((expectedErrors.isEmpty) == (failureCode == null)) {
          throw const FormatException(
            'Tool fixtures require exactly one of toolErrorCodes or failureCode.',
          );
        }
        if (failureCode != null &&
            (failureCode is! String || failureCode.trim().isEmpty)) {
          throw const FormatException('failureCode must be non-empty text.');
        }
    }
  }

  static void _validateTextChecks(Map<String, Object?> expectation) {
    final exact = expectation['exact'];
    if (exact != null && exact is! String) {
      throw const FormatException('The exact check must be text.');
    }
    final requiresQuestion = expectation['requiresQuestion'];
    if (requiresQuestion != null && requiresQuestion is! bool) {
      throw const FormatException('requiresQuestion must be a boolean.');
    }
    _stringGroups(expectation['requiredAny'], 'requiredAny');
    _strings(expectation['forbiddenAny'], 'forbiddenAny');
    _strings(expectation['reviewCriteria'], 'reviewCriteria');
  }
}

class AiQualityRunMetadata {
  const AiQualityRunMetadata({
    required this.modelId,
    required this.modelVersion,
    required this.repetitions,
  });

  final String modelId;
  final String modelVersion;
  final int repetitions;
}

class AiQualityCaseResult {
  AiQualityCaseResult({
    required this.caseId,
    required this.repetition,
    required this.workflow,
    required this.language,
    required List<String> coverage,
    required this.outcome,
    required this.duration,
    required List<String> diagnostics,
    required List<String> reviewCriteria,
    this.output,
    this.failureCode,
    this.usage,
  }) : coverage = List.unmodifiable(coverage),
       diagnostics = List.unmodifiable(diagnostics),
       reviewCriteria = List.unmodifiable(reviewCriteria);

  final String caseId;
  final int repetition;
  final AiQualityWorkflow workflow;
  final String language;
  final List<String> coverage;
  final AiQualityOutcome outcome;
  final Duration duration;
  final List<String> diagnostics;
  final List<String> reviewCriteria;
  final String? output;
  final String? failureCode;
  final AiTokenUsage? usage;

  Map<String, Object?> toJson() => {
    'caseId': caseId,
    'repetition': repetition,
    'workflow': workflow.name,
    'language': language,
    'coverage': coverage,
    'outcome': outcome.name,
    'durationMs': duration.inMilliseconds,
    'diagnostics': diagnostics,
    'reviewCriteria': reviewCriteria,
    if (output != null) 'output': output,
    if (failureCode != null) 'failureCode': failureCode,
    if (usage != null)
      'usage': {
        'inputTokens': usage!.inputTokens,
        'outputTokens': usage!.outputTokens,
        if (usage!.totalTokens != null) 'totalTokens': usage!.totalTokens,
      },
  };
}

class AiQualityReport {
  AiQualityReport({
    required this.suite,
    required this.metadata,
    required this.startedAt,
    required this.completedAt,
    required List<AiQualityCaseResult> results,
    required this.profile,
  }) : results = List.unmodifiable(results);

  final AiQualitySuite suite;
  final AiQualityRunMetadata metadata;
  final DateTime startedAt;
  final DateTime completedAt;
  final List<AiQualityCaseResult> results;
  final AiConnectionProfile profile;

  bool get passed =>
      results.every((result) => result.outcome == AiQualityOutcome.passed);

  Map<String, Object?> toJson() {
    final counts = {
      for (final outcome in AiQualityOutcome.values)
        outcome.name:
            results.where((result) => result.outcome == outcome).length,
    };
    return {
      'schemaVersion': 1,
      'suite': {
        'version': suite.suiteVersion,
        'description': suite.description,
      },
      'run': {
        'startedAt': startedAt.toUtc().toIso8601String(),
        'completedAt': completedAt.toUtc().toIso8601String(),
        'model': {'id': metadata.modelId, 'version': metadata.modelVersion},
        'protocol': profile.protocol.name,
        'repetitions': metadata.repetitions,
        'generationSettings': {
          'reasoningEffort': profile.reasoningEffort.name,
          'maxOutputTokens': profile.maxOutputTokens,
          'connectionTimeoutSeconds': profile.connectionTimeout.inSeconds,
          'streamIdleTimeoutSeconds': profile.responseIdleTimeout.inSeconds,
        },
        'prompts': {
          'chatSystemInstruction': profile.systemPrompt,
          'noteToTasksSystemInstruction':
              AiNoteTaskPromptBuilder.systemInstruction,
        },
      },
      'summary': {'total': results.length, ...counts},
      'results': [for (final result in results) result.toJson()],
    };
  }
}

class AiQualityEvaluator {
  AiQualityEvaluator({
    required AiAssistantRepository repository,
    DateTime Function()? clock,
  }) : _repository = repository,
       _clock = clock ?? DateTime.now;

  final AiAssistantRepository _repository;
  final DateTime Function() _clock;

  Future<AiQualityReport> run({
    required AiQualitySuite suite,
    required AiConnectionProfile profile,
    required AiQualityRunMetadata metadata,
    Set<String>? caseIds,
  }) async {
    if (metadata.repetitions < 1) {
      throw ArgumentError.value(
        metadata.repetitions,
        'repetitions',
        'must be at least one',
      );
    }
    final selected =
        caseIds == null
            ? suite.cases
            : suite.cases.where((value) => caseIds.contains(value.id)).toList();
    if (caseIds != null && selected.length != caseIds.length) {
      final found = selected.map((value) => value.id).toSet();
      final missing = caseIds.difference(found).join(', ');
      throw ArgumentError('Unknown evaluation case id(s): $missing.');
    }

    final startedAt = _clock();
    final results = <AiQualityCaseResult>[];
    for (var repetition = 1; repetition <= metadata.repetitions; repetition++) {
      for (final evaluationCase in selected) {
        results.add(
          await _runCase(
            evaluationCase,
            profile: profile,
            repetition: repetition,
          ),
        );
      }
    }
    return AiQualityReport(
      suite: suite,
      metadata: metadata,
      startedAt: startedAt,
      completedAt: _clock(),
      results: results,
      profile: profile,
    );
  }

  Future<AiQualityCaseResult> _runCase(
    AiQualityCase evaluationCase, {
    required AiConnectionProfile profile,
    required int repetition,
  }) async {
    final stopwatch = Stopwatch()..start();
    if (evaluationCase.workflow == AiQualityWorkflow.parserFixture) {
      return _runParserFixture(evaluationCase, repetition, stopwatch);
    }
    if (evaluationCase.workflow == AiQualityWorkflow.toolProtocolFixture) {
      return _runToolProtocolFixture(
        evaluationCase,
        profile,
        repetition,
        stopwatch,
      );
    }

    final request = _requestFor(evaluationCase, profile, repetition);
    final collected = await _collect(request);
    stopwatch.stop();
    if (collected.failure != null) {
      final failure = collected.failure!;
      return _result(
        evaluationCase,
        repetition,
        stopwatch.elapsed,
        outcome:
            _isApplicationResponseFailure(failure.code)
                ? AiQualityOutcome.applicationFailure
                : AiQualityOutcome.transportFailure,
        output: collected.output,
        failureCode: failure.code,
        diagnostics: [failure.message],
        usage: collected.usage,
      );
    }
    if (collected.toolCallReceived) {
      return _result(
        evaluationCase,
        repetition,
        stopwatch.elapsed,
        outcome: AiQualityOutcome.applicationFailure,
        output: collected.output,
        failureCode: 'unexpected_tool_call',
        diagnostics: const [
          'The model requested a tool instead of returning evaluation output.',
        ],
        usage: collected.usage,
      );
    }
    if (!collected.completed) {
      return _result(
        evaluationCase,
        repetition,
        stopwatch.elapsed,
        outcome: AiQualityOutcome.transportFailure,
        output: collected.output,
        failureCode: 'incomplete_stream',
        diagnostics: const [
          'The response stream ended without a completion event.',
        ],
        usage: collected.usage,
      );
    }

    final output = collected.output;
    if (evaluationCase.workflow == AiQualityWorkflow.noteToTasks) {
      final AiTaskProposal proposal;
      try {
        proposal = AiTaskProposalParser.parse(output);
      } on AiTaskProposalFormatException catch (error) {
        return _result(
          evaluationCase,
          repetition,
          stopwatch.elapsed,
          outcome: AiQualityOutcome.applicationFailure,
          output: output,
          failureCode: 'proposal_${error.code.name}',
          diagnostics: [error.message],
          usage: collected.usage,
        );
      }
      final diagnostics = _taskDiagnostics(evaluationCase, proposal);
      return _result(
        evaluationCase,
        repetition,
        stopwatch.elapsed,
        outcome:
            diagnostics.isEmpty
                ? AiQualityOutcome.passed
                : AiQualityOutcome.qualityFailure,
        output: output,
        diagnostics: diagnostics,
        usage: collected.usage,
      );
    }

    final diagnostics = _textDiagnostics(evaluationCase.expectation, output);
    return _result(
      evaluationCase,
      repetition,
      stopwatch.elapsed,
      outcome:
          diagnostics.isEmpty
              ? AiQualityOutcome.passed
              : AiQualityOutcome.qualityFailure,
      output: output,
      diagnostics: diagnostics,
      usage: collected.usage,
    );
  }

  AiQualityCaseResult _runParserFixture(
    AiQualityCase evaluationCase,
    int repetition,
    Stopwatch stopwatch,
  ) {
    final expectedCode =
        evaluationCase.expectation['parserErrorCode'] as String;
    try {
      AiTaskProposalParser.parse(evaluationCase.input['response'] as String);
      stopwatch.stop();
      return _result(
        evaluationCase,
        repetition,
        stopwatch.elapsed,
        outcome: AiQualityOutcome.applicationFailure,
        failureCode: 'guardrail_not_triggered',
        diagnostics: [
          'Expected parser rejection $expectedCode, but the response was accepted.',
        ],
      );
    } on AiTaskProposalFormatException catch (error) {
      stopwatch.stop();
      final matches = error.code.name == expectedCode;
      return _result(
        evaluationCase,
        repetition,
        stopwatch.elapsed,
        outcome:
            matches
                ? AiQualityOutcome.passed
                : AiQualityOutcome.applicationFailure,
        failureCode: matches ? null : 'unexpected_parser_error',
        diagnostics:
            matches
                ? const []
                : [
                  'Expected parser rejection $expectedCode, got ${error.code.name}.',
                ],
      );
    } catch (error) {
      stopwatch.stop();
      return _result(
        evaluationCase,
        repetition,
        stopwatch.elapsed,
        outcome: AiQualityOutcome.applicationFailure,
        failureCode: 'unexpected_parser_exception',
        diagnostics: ['$error'],
      );
    }
  }

  Future<AiQualityCaseResult> _runToolProtocolFixture(
    AiQualityCase evaluationCase,
    AiConnectionProfile profile,
    int repetition,
    Stopwatch stopwatch,
  ) async {
    final calls = _toolCallsFrom(evaluationCase.input);
    final rawAuthorization = _object(
      evaluationCase.input['authorization'],
      'Tool fixture authorization must be an object.',
    );
    final authorization = AiReadToolAuthorization(
      allowActiveTasks: rawAuthorization['allowActiveTasks'] as bool,
    );
    final repository = _ToolFixtureRepository(calls);
    final readService = _RejectingFixtureReadService();
    final toolProfile = profile.copyWith(
      capabilityOverrides: {
        ...profile.capabilityOverrides,
        AiCapability.tools: true,
      },
    );
    final coordinator = AiReadToolCoordinator(
      assistantRepository: repository,
      readService: readService,
    );

    try {
      final handle = await coordinator.startResponse(
        AiChatRequest(
          connectionProfile: toolProfile,
          conversationId: 'quality:${evaluationCase.id}:$repetition',
          messages: [
            AiChatMessage(
              id: 'quality:${evaluationCase.id}:$repetition:user',
              role: AiMessageRole.user,
              content: 'Exercise the committed tool-protocol fixture.',
              createdAt: DateTime.utc(2000),
            ),
          ],
          readToolAuthorization: authorization,
        ),
        scope: AiReadToolExecutionScope(authorization: authorization),
      );
      final events = await handle.events.toList();
      stopwatch.stop();
      final failureCodes =
          [
            for (final event in events)
              if (event is AiResponseFailed) event.code,
          ].whereType<String>().toList();
      final toolErrorCodes =
          [
            for (final request in repository.requests)
              for (final message in request.continuationMessages)
                if (message is AiToolResultMessage && message.isError)
                  message.result['code']?.toString(),
          ].whereType<String>().toList();
      final expectedFailure = evaluationCase.expectation['failureCode'];
      final expectedToolErrors = _strings(
        evaluationCase.expectation['toolErrorCodes'],
        'toolErrorCodes',
      );
      final diagnostics = <String>[];
      if (expectedFailure is String) {
        if (failureCodes.length != 1 ||
            failureCodes.single != expectedFailure) {
          diagnostics.add(
            'Expected session failure $expectedFailure, got '
            '${failureCodes.isEmpty ? 'none' : failureCodes.join(', ')}.',
          );
        }
      } else if (!_sameStrings(toolErrorCodes, expectedToolErrors)) {
        diagnostics.add(
          'Expected tool errors ${expectedToolErrors.join(', ')}, got '
          '${toolErrorCodes.isEmpty ? 'none' : toolErrorCodes.join(', ')}.',
        );
      }
      if (readService.readCount != 0) {
        diagnostics.add(
          'Rejected calls reached the application read service '
          '${readService.readCount} time(s).',
        );
      }
      return _result(
        evaluationCase,
        repetition,
        stopwatch.elapsed,
        outcome:
            diagnostics.isEmpty
                ? AiQualityOutcome.passed
                : AiQualityOutcome.applicationFailure,
        output: jsonEncode({
          'failureCodes': failureCodes,
          'toolErrorCodes': toolErrorCodes,
          'applicationReads': readService.readCount,
        }),
        failureCode:
            diagnostics.isEmpty ? null : 'tool_protocol_guardrail_regression',
        diagnostics: diagnostics,
      );
    } catch (error) {
      stopwatch.stop();
      return _result(
        evaluationCase,
        repetition,
        stopwatch.elapsed,
        outcome: AiQualityOutcome.applicationFailure,
        failureCode: 'tool_fixture_exception',
        diagnostics: ['Could not execute the tool fixture: $error'],
      );
    }
  }

  AiChatRequest _requestFor(
    AiQualityCase evaluationCase,
    AiConnectionProfile profile,
    int repetition,
  ) {
    late final String systemInstruction;
    late final String userMessage;
    final AiApplicationContextEnvelope? applicationContext;
    if (evaluationCase.workflow == AiQualityWorkflow.noteToTasks) {
      final prompt = AiNoteTaskPromptBuilder.build(
        noteTitle: evaluationCase.input['noteTitle'] as String,
        noteContent: evaluationCase.input['noteContent'] as String,
      );
      systemInstruction = prompt.systemInstruction;
      userMessage = prompt.userMessage;
      applicationContext = null;
    } else {
      systemInstruction = profile.systemPrompt;
      userMessage = evaluationCase.input['message'] as String;
      applicationContext =
          evaluationCase.workflow == AiQualityWorkflow.attachedContext
              ? _attachedContextFrom(evaluationCase.input)
              : null;
    }
    return AiChatRequest(
      connectionProfile: profile,
      conversationId: 'quality:${evaluationCase.id}:$repetition',
      systemInstruction:
          systemInstruction.trim().isEmpty ? null : systemInstruction.trim(),
      applicationContext: applicationContext,
      messages: [
        AiChatMessage(
          id: 'quality:${evaluationCase.id}:$repetition:user',
          role: AiMessageRole.user,
          content: userMessage,
          createdAt: DateTime.utc(2000),
        ),
      ],
    );
  }

  Future<_CollectedResponse> _collect(AiChatRequest request) async {
    try {
      final handle = await _repository.startResponse(request);
      final output = StringBuffer();
      AiResponseFailed? failure;
      AiTokenUsage? usage;
      var completed = false;
      var toolCallReceived = false;
      await for (final event in handle.events) {
        switch (event) {
          case AiTextDelta(:final text):
            output.write(text);
          case AiReasoningDelta():
            break;
          case AiResponseCompleted(usage: final responseUsage):
            completed = true;
            usage = responseUsage ?? usage;
          case AiResponseFailed():
            failure = event;
          case AiToolCallRequested():
            toolCallReceived = true;
        }
      }
      return _CollectedResponse(
        output: output.toString(),
        failure: failure,
        completed: completed,
        toolCallReceived: toolCallReceived,
        usage: usage,
      );
    } catch (error) {
      return _CollectedResponse(
        output: '',
        failure: AiResponseFailed(
          error: error,
          message: 'Could not execute the model request: $error',
          code: 'request_exception',
          retryable: true,
        ),
        completed: false,
        toolCallReceived: false,
      );
    }
  }

  static List<String> _taskDiagnostics(
    AiQualityCase evaluationCase,
    AiTaskProposal proposal,
  ) {
    final expectation = evaluationCase.expectation;
    final diagnostics = <String>[];
    final minTasks = expectation['minTasks'] as int;
    final maxTasks = expectation['maxTasks'] as int;
    if (proposal.tasks.length < minTasks || proposal.tasks.length > maxTasks) {
      diagnostics.add(
        'Expected $minTasks..$maxTasks tasks, got ${proposal.tasks.length}.',
      );
    }
    diagnostics.addAll(
      _textDiagnostics(
        expectation,
        proposal.tasks.map((task) => task.title).join('\n'),
      ),
    );
    return diagnostics;
  }

  static List<String> _textDiagnostics(
    Map<String, Object?> expectation,
    String output,
  ) {
    final diagnostics = <String>[];
    final normalized = output.toLowerCase();
    final exact = expectation['exact'];
    if (exact is String && output.trim() != exact) {
      diagnostics.add('Expected the exact response "$exact".');
    }
    for (final alternatives in _stringGroups(
      expectation['requiredAny'],
      'requiredAny',
    )) {
      if (!alternatives.any(
        (value) => normalized.contains(value.toLowerCase()),
      )) {
        diagnostics.add(
          'Missing required concept (${alternatives.join(' OR ')}).',
        );
      }
    }
    for (final forbidden in _strings(
      expectation['forbiddenAny'],
      'forbiddenAny',
    )) {
      if (normalized.contains(forbidden.toLowerCase())) {
        diagnostics.add('Included forbidden concept "$forbidden".');
      }
    }
    if (expectation['requiresQuestion'] == true && !output.contains('?')) {
      diagnostics.add('Expected a clarifying question.');
    }
    return diagnostics;
  }

  static AiQualityCaseResult _result(
    AiQualityCase evaluationCase,
    int repetition,
    Duration duration, {
    required AiQualityOutcome outcome,
    List<String> diagnostics = const [],
    String? output,
    String? failureCode,
    AiTokenUsage? usage,
  }) {
    return AiQualityCaseResult(
      caseId: evaluationCase.id,
      repetition: repetition,
      workflow: evaluationCase.workflow,
      language: evaluationCase.language,
      coverage: evaluationCase.coverage,
      outcome: outcome,
      duration: duration,
      diagnostics: diagnostics,
      reviewCriteria: _strings(
        evaluationCase.expectation['reviewCriteria'],
        'reviewCriteria',
      ),
      output: output,
      failureCode: failureCode,
      usage: usage,
    );
  }

  static bool _isApplicationResponseFailure(String? code) =>
      code == 'empty_response' || code == 'invalid_response';
}

class _CollectedResponse {
  const _CollectedResponse({
    required this.output,
    required this.failure,
    required this.completed,
    required this.toolCallReceived,
    this.usage,
  });

  final String output;
  final AiResponseFailed? failure;
  final bool completed;
  final bool toolCallReceived;
  final AiTokenUsage? usage;
}

AiApplicationContextEnvelope _attachedContextFrom(Map<String, Object?> input) {
  final fixture = _object(
    input['applicationContext'],
    'Attached-context input must contain an applicationContext object.',
  );
  _requireExactKeys(fixture, const {
    'generatedAt',
    'tasks',
    'omittedCount',
    'payloadTruncated',
  });
  final generatedAt = DateTime.tryParse(
    _nonEmptyString(fixture, 'generatedAt'),
  );
  if (generatedAt == null || !generatedAt.isUtc) {
    throw const FormatException('generatedAt must be a UTC RFC 3339 value.');
  }
  final omittedCount = _integer(fixture, 'omittedCount');
  if (omittedCount < 0) {
    throw const FormatException('omittedCount must not be negative.');
  }
  final payloadTruncated = fixture['payloadTruncated'];
  if (payloadTruncated is! bool) {
    throw const FormatException('payloadTruncated must be a boolean.');
  }
  final rawTasks = fixture['tasks'];
  if (rawTasks is! List || rawTasks.isEmpty) {
    throw const FormatException(
      'Attached-context fixtures need at least one task.',
    );
  }
  if (rawTasks.length > AiApplicationContextLimits.maxActiveTasks) {
    throw const FormatException(
      'Attached-context fixture exceeds the active-task limit.',
    );
  }
  final tasks = <AiTaskContextItem>[];
  for (final rawTask in rawTasks) {
    final task = _object(rawTask, 'Every attached task must be an object.');
    _requireExactKeys(task, const {'title', 'isCompleted'});
    final title = _nonEmptyString(task, 'title');
    if (title.length > AiApplicationContextLimits.maxTaskTitleCharacters) {
      throw const FormatException('An attached task title is too long.');
    }
    final isCompleted = task['isCompleted'];
    if (isCompleted is! bool) {
      throw const FormatException('isCompleted must be a boolean.');
    }
    tasks.add(AiTaskContextItem(title: title, isCompleted: isCompleted));
  }
  final envelope = AiApplicationContextEnvelope(
    generatedAt: generatedAt,
    attachments: [
      AiActiveTasksContextAttachment(tasks: tasks, omittedCount: omittedCount),
    ],
    payloadTruncated: payloadTruncated,
  );
  if (envelope.serializedCharacterCount >
      AiApplicationContextLimits.maxPayloadCharacters) {
    throw const FormatException(
      'Attached-context fixture exceeds the payload limit.',
    );
  }
  return envelope;
}

List<AiToolCall> _toolCallsFrom(Map<String, Object?> input) {
  final rawCalls = input['toolCalls'];
  if (rawCalls is! List || rawCalls.isEmpty) {
    throw const FormatException('Tool fixtures need at least one tool call.');
  }
  return [
    for (final rawCall in rawCalls)
      () {
        final call = _object(rawCall, 'Every tool call must be an object.');
        _requireExactKeys(call, const {'id', 'name', 'arguments'});
        return AiToolCall(
          id: _nonEmptyString(call, 'id'),
          name: _nonEmptyString(call, 'name'),
          arguments: _object(
            call['arguments'],
            'Tool-call arguments must be an object.',
          ),
        );
      }(),
  ];
}

bool _sameStrings(List<String> actual, List<String> expected) {
  if (actual.length != expected.length) return false;
  for (var index = 0; index < actual.length; index++) {
    if (actual[index] != expected[index]) return false;
  }
  return true;
}

void _requireExactKeys(Map<String, Object?> value, Set<String> expected) {
  final keys = value.keys.toSet();
  if (keys.length != expected.length || !keys.containsAll(expected)) {
    throw FormatException(
      'Expected exactly these keys: ${expected.join(', ')}.',
    );
  }
}

class _ToolFixtureRepository implements AiAssistantRepository {
  _ToolFixtureRepository(this.calls);

  final List<AiToolCall> calls;
  final List<AiChatRequest> requests = [];

  @override
  Future<AiResponseHandle> startResponse(AiChatRequest request) async {
    requests.add(request);
    final events =
        requests.length == 1
            ? <AiStreamEvent>[
              for (final call in calls) AiToolCallRequested.fromCall(call),
              const AiResponseCompleted(finishReason: 'tool_calls'),
            ]
            : const <AiStreamEvent>[
              AiTextDelta('Tool fixture completed.'),
              AiResponseCompleted(finishReason: 'stop'),
            ];
    return StreamAiResponseHandle(
      events: Stream.fromIterable(events),
      onCancel: () async {},
    );
  }

  @override
  Future<List<AiModelInfo>> listModels(AiConnectionProfile profile) async =>
      const [];

  @override
  Future<AiConnectionResult> testConnection(
    AiConnectionProfile profile,
  ) async => const AiConnectionResult.connected();
}

class _RejectingFixtureReadService implements AiApplicationContextReadService {
  var readCount = 0;

  Never _unexpectedRead() {
    readCount++;
    throw StateError('A rejected quality fixture reached application data.');
  }

  @override
  Future<AiApplicationContextEnvelope> eventsForDateRange({
    required AiApplicationReadScope scope,
    required CalendarQueryRange range,
    int limit = AiApplicationContextLimits.maxEvents,
  }) async => _unexpectedRead();

  @override
  Future<AiApplicationContextEnvelope> getNote({
    required AiApplicationReadScope scope,
    required String noteId,
  }) async => _unexpectedRead();

  @override
  Future<AiApplicationContextEnvelope> listTasks({
    required AiApplicationReadScope scope,
    int limit = AiApplicationContextLimits.maxActiveTasks,
  }) async => _unexpectedRead();

  @override
  Future<AiNoteSearchContextResult> searchNotes({
    required AiApplicationReadScope scope,
    required String query,
    int limit = AiApplicationContextReadLimits.maxSearchResults,
  }) async => _unexpectedRead();
}

Map<String, Object?> _object(Object? value, String message) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException(message);
  }
  return Map<String, Object?>.from(value);
}

String _nonEmptyString(Map<String, Object?> json, String key) {
  final value = _string(json, key);
  if (value.trim().isEmpty) {
    throw FormatException('$key must not be empty.');
  }
  return value;
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key must be text.');
  return value;
}

int _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

List<String> _strings(Object? value, String name) {
  if (value == null) return const [];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('$name must be a list of strings.');
  }
  return List<String>.from(value);
}

List<List<String>> _stringGroups(Object? value, String name) {
  if (value == null) return const [];
  if (value is! List) {
    throw FormatException('$name must be a list of string lists.');
  }
  return value.map((group) {
    final strings = _strings(group, name);
    if (strings.isEmpty) {
      throw FormatException('$name groups must not be empty.');
    }
    return strings;
  }).toList();
}
