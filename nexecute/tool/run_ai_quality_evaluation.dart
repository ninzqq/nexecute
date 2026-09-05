import 'dart:convert';
import 'dart:io';

import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/ai/domain/ai_protocol.dart';
import 'package:nexecute/ai/infrastructure/open_ai_compatible_assistant_repository.dart';

import 'ai_quality_evaluation.dart';

const _defaultSuitePath = 'evaluation/ai_quality_cases.v1.json';

Future<void> main(List<String> arguments) async {
  final _Options options;
  try {
    options = _Options.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.write(_usage);
    exitCode = 1;
    return;
  }
  if (options.showHelp) {
    stdout.write(_usage);
    return;
  }

  final suiteFile = File(options.suitePath);
  if (!suiteFile.existsSync()) {
    stderr.writeln('Evaluation suite not found: ${options.suitePath}');
    exitCode = 1;
    return;
  }

  final AiQualitySuite suite;
  try {
    suite = AiQualitySuite.fromJsonString(await suiteFile.readAsString());
  } on Object catch (error) {
    stderr.writeln('Could not load evaluation suite: $error');
    exitCode = 1;
    return;
  }

  if (options.dryRun) {
    stdout.writeln(
      'Suite ${suite.suiteVersion}: ${suite.cases.length} valid cases',
    );
    for (final evaluationCase in suite.cases) {
      stdout.writeln(
        '${evaluationCase.id}\t${evaluationCase.workflow.name}\t'
        '${evaluationCase.language}\t${evaluationCase.coverage.join(',')}',
      );
    }
    return;
  }

  if (options.baseUrl == null ||
      options.modelId == null ||
      options.modelVersion == null) {
    stderr.writeln(
      '--base-url, --model, and --model-version are required for a live run.',
    );
    stderr.write(_usage);
    exitCode = 1;
    return;
  }

  final baseUrl = Uri.tryParse(options.baseUrl!);
  if (baseUrl == null ||
      !baseUrl.hasScheme ||
      (baseUrl.scheme != 'http' && baseUrl.scheme != 'https')) {
    stderr.writeln('--base-url must be a valid HTTP(S) URL.');
    exitCode = 1;
    return;
  }

  final profile = AiConnectionProfile(
    id: 'quality-evaluation',
    name: 'Quality evaluation',
    protocol: AiProtocol.openAiCompatibleChat,
    baseUrl: baseUrl,
    modelId: options.modelId!,
    contextWindowTokens: options.contextWindowTokens,
    allowMultipleSkills: options.allowMultipleSkills,
    reasoningEffort: AiReasoningEffort.none,
  );
  final repository = OpenAiCompatibleAssistantRepository();
  try {
    final evaluator = AiQualityEvaluator(repository: repository);
    final report = await evaluator.run(
      suite: suite,
      profile: profile,
      metadata: AiQualityRunMetadata(
        modelId: options.modelId!,
        modelVersion: options.modelVersion!,
        repetitions: options.repetitions,
      ),
      caseIds: options.caseIds,
    );
    final outputFile = File(
      options.outputPath ??
          _defaultOutputPath(options.modelId!, options.modelVersion!),
    );
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(report.toJson())}\n',
    );

    final summary = report.toJson()['summary'] as Map<String, Object?>;
    stdout.writeln('Report: ${outputFile.path}');
    stdout.writeln(
      'Passed ${summary['passed']}/${summary['total']}; '
      'transport ${summary['transportFailure']}, '
      'application ${summary['applicationFailure']}, '
      'quality ${summary['qualityFailure']}.',
    );
    if (!report.passed) exitCode = 2;
  } finally {
    repository.dispose();
  }
}

String _defaultOutputPath(String modelId, String modelVersion) {
  final timestamp = DateTime.now()
      .toUtc()
      .toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '-');
  final model = _safeFilePart(modelId);
  final version = _safeFilePart(modelVersion);
  return 'evaluation/results/$timestamp'
      '__${model}__$version.json';
}

String _safeFilePart(String value) {
  final sanitized = value.replaceAll(RegExp('[^a-zA-Z0-9._-]+'), '-');
  return sanitized.isEmpty ? 'unknown' : sanitized;
}

class _Options {
  const _Options({
    required this.suitePath,
    required this.repetitions,
    required this.dryRun,
    required this.showHelp,
    this.baseUrl,
    this.modelId,
    this.modelVersion,
    this.outputPath,
    this.caseIds,
    this.contextWindowTokens = aiDefaultContextWindowTokens,
    this.allowMultipleSkills = false,
  });

  factory _Options.parse(List<String> arguments) {
    var suitePath = _defaultSuitePath;
    var repetitions = 1;
    var contextWindowTokens = aiDefaultContextWindowTokens;
    var allowMultipleSkills = false;
    var dryRun = false;
    var showHelp = false;
    String? baseUrl;
    String? modelId;
    String? modelVersion;
    String? outputPath;
    Set<String>? caseIds;

    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      String nextValue() {
        if (index + 1 >= arguments.length) {
          throw FormatException('Missing value after $argument.');
        }
        return arguments[++index];
      }

      switch (argument) {
        case '--context-window':
          contextWindowTokens = int.parse(nextValue());
          if (contextWindowTokens < 2048 ||
              contextWindowTokens > aiMaxContextWindowTokens) {
            throw const FormatException('Invalid context window.');
          }
        case '--allow-multiple-skills':
          allowMultipleSkills = true;
        case '--suite':
          suitePath = nextValue();
        case '--base-url':
          baseUrl = nextValue();
        case '--model':
          modelId = nextValue();
        case '--model-version':
          modelVersion = nextValue();
        case '--output':
          outputPath = nextValue();
        case '--repetitions':
          repetitions = int.parse(nextValue());
          if (repetitions < 1) {
            throw const FormatException('--repetitions must be at least one.');
          }
        case '--case':
          caseIds = {
            for (final value in nextValue().split(','))
              if (value.trim().isNotEmpty) value.trim(),
          };
        case '--dry-run':
          dryRun = true;
        case '--help' || '-h':
          showHelp = true;
        default:
          throw FormatException('Unknown argument: $argument.');
      }
    }
    return _Options(
      suitePath: suitePath,
      repetitions: repetitions,
      dryRun: dryRun,
      showHelp: showHelp,
      baseUrl: baseUrl,
      modelId: modelId,
      modelVersion: modelVersion,
      outputPath: outputPath,
      caseIds: caseIds,
      contextWindowTokens: contextWindowTokens,
      allowMultipleSkills: allowMultipleSkills,
    );
  }

  final String suitePath;
  final int repetitions;
  final bool dryRun;
  final bool showHelp;
  final String? baseUrl;
  final String? modelId;
  final String? modelVersion;
  final String? outputPath;
  final Set<String>? caseIds;
  final int contextWindowTokens;
  final bool allowMultipleSkills;
}

const _usage = '''
Run Nexecute's repeatable AI quality evaluation.

Validate and list the committed suite without making network requests:
  dart run tool/run_ai_quality_evaluation.dart --dry-run

Run against an OpenAI-compatible endpoint:
  dart run tool/run_ai_quality_evaluation.dart \\
    --base-url http://192.0.2.10:11434/v1 \\
    --model model-id \\
    --model-version model-version

Options:
  --suite <path>          Evaluation suite JSON (default: $_defaultSuitePath)
  --base-url <url>        OpenAI-compatible API base URL; never recorded
  --model <id>            Requested model identifier
  --model-version <text>  Exact model version, tag, or digest for comparison
  --output <path>         Report path (default: evaluation/results/...)
  --repetitions <count>   Runs per case (default: 1)
  --context-window <n>    Verified runtime context tokens (default: 8192)
  --allow-multiple-skills Enable explicit multi-skill evaluation
  --case <id,id>          Run only the listed stable case IDs
  --dry-run               Validate and list cases without contacting a server
  --help                  Show this help
''';
