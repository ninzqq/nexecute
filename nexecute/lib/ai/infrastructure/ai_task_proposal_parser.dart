import 'dart:convert';

import 'package:nexecute/ai/domain/ai_task_proposal.dart';

abstract final class AiTaskProposalParser {
  static AiTaskProposal parse(String response) {
    if (response.length > aiMaxTaskProposalResponseCharacters) {
      throw const AiTaskProposalFormatException(
        AiTaskProposalErrorCode.responseTooLarge,
        'The model response was too large to be a task proposal.',
      );
    }

    final jsonText = _unwrapJsonFence(response.trim());
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException {
      throw const AiTaskProposalFormatException(
        AiTaskProposalErrorCode.invalidJson,
        'The model did not return valid JSON.',
      );
    }

    final root = _stringMap(decoded, 'The proposal must be a JSON object.');
    if (!_hasExactKeys(root, const {'schemaVersion', 'tasks'})) {
      throw const AiTaskProposalFormatException(
        AiTaskProposalErrorCode.invalidShape,
        'The proposal contains missing or unsupported fields.',
      );
    }

    final version = root['schemaVersion'];
    if (version is! int || version != aiTaskProposalSchemaVersion) {
      throw const AiTaskProposalFormatException(
        AiTaskProposalErrorCode.unsupportedVersion,
        'The task-proposal version is not supported.',
      );
    }

    final rawTasks = root['tasks'];
    if (rawTasks is! List) {
      throw const AiTaskProposalFormatException(
        AiTaskProposalErrorCode.invalidShape,
        'The proposal tasks must be a JSON array.',
      );
    }
    if (rawTasks.length > aiMaxProposedTasks) {
      throw const AiTaskProposalFormatException(
        AiTaskProposalErrorCode.tooManyTasks,
        'The model proposed too many tasks.',
      );
    }

    final tasks = <AiProposedTask>[];
    final normalizedTitles = <String>{};
    for (final rawTask in rawTasks) {
      final task = _stringMap(rawTask, 'Each proposed task must be an object.');
      if (!_hasExactKeys(task, const {'title'})) {
        throw const AiTaskProposalFormatException(
          AiTaskProposalErrorCode.invalidTask,
          'A proposed task contains missing or unsupported fields.',
        );
      }
      final rawTitle = task['title'];
      if (rawTitle is! String) {
        throw const AiTaskProposalFormatException(
          AiTaskProposalErrorCode.invalidTask,
          'Every proposed task must have a text title.',
        );
      }
      final title = rawTitle.trim();
      if (title.isEmpty ||
          title.length > aiMaxProposedTaskTitleCharacters ||
          title.contains('\n') ||
          title.contains('\r')) {
        throw const AiTaskProposalFormatException(
          AiTaskProposalErrorCode.invalidTask,
          'Every proposed task title must be one non-empty line of at most 200 characters.',
        );
      }
      if (!normalizedTitles.add(title.toLowerCase())) {
        throw const AiTaskProposalFormatException(
          AiTaskProposalErrorCode.duplicateTask,
          'The model proposed the same task more than once.',
        );
      }
      tasks.add(AiProposedTask(title: title));
    }

    return AiTaskProposal(schemaVersion: version, tasks: tasks);
  }

  static Map<String, Object?> _stringMap(Object? value, String message) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw AiTaskProposalFormatException(
        AiTaskProposalErrorCode.invalidShape,
        message,
      );
    }
    return Map<String, Object?>.from(value);
  }

  static bool _hasExactKeys(Map<String, Object?> value, Set<String> expected) {
    return value.length == expected.length &&
        value.keys.every(expected.contains);
  }

  static String _unwrapJsonFence(String response) {
    final match = RegExp(
      r'^```(?:json)?\s*(.*?)\s*```$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(response);
    return match?.group(1)?.trim() ?? response;
  }
}
