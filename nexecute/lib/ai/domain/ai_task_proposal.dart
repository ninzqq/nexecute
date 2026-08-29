const aiTaskProposalSchemaVersion = 1;
const aiMaxProposedTasks = 10;
const aiMaxProposedTaskTitleCharacters = 200;
const aiMaxTaskProposalResponseCharacters = 16000;

class AiProposedTask {
  const AiProposedTask({required this.title});

  final String title;

  AiProposedTask copyWith({String? title}) =>
      AiProposedTask(title: title ?? this.title);
}

class AiTaskProposal {
  AiTaskProposal({
    required this.schemaVersion,
    required List<AiProposedTask> tasks,
  }) : tasks = List.unmodifiable(tasks);

  final int schemaVersion;
  final List<AiProposedTask> tasks;
}

enum AiTaskProposalErrorCode {
  responseTooLarge,
  invalidJson,
  invalidShape,
  unsupportedVersion,
  tooManyTasks,
  invalidTask,
  duplicateTask,
}

final class AiTaskProposalFormatException extends FormatException {
  const AiTaskProposalFormatException(this.code, String message)
    : super(message);

  final AiTaskProposalErrorCode code;
}
