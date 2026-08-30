const aiEventProposalSchemaVersion = 1;
const aiMaxProposedEventTitleCharacters = 200;
const aiMaxProposedEventDescriptionCharacters = 4000;
const aiMaxEventProposalResponseCharacters = 16000;
const aiMaxProposedEventSpanDays = 366;

class AiProposedEvent {
  const AiProposedEvent({
    required this.title,
    required this.description,
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
    required this.isAllDay,
  });

  final String title;
  final String description;

  /// A validated local calendar date in YYYY-MM-DD format.
  final String? startDate;

  /// A validated local wall-clock time in HH:mm format.
  final String? startTime;

  /// A validated local calendar date in YYYY-MM-DD format.
  final String? endDate;

  /// A validated local wall-clock time in HH:mm format.
  final String? endTime;

  /// Null means the source note did not establish whether the event is timed.
  final bool? isAllDay;

  bool get hasCompleteSchedule => switch (isAllDay) {
    true => startDate != null && endDate != null,
    false =>
      startDate != null &&
          startTime != null &&
          endDate != null &&
          endTime != null,
    null => false,
  };
}

class AiEventProposal {
  const AiEventProposal({required this.schemaVersion, required this.event});

  final int schemaVersion;
  final AiProposedEvent? event;
}

enum AiEventProposalErrorCode {
  responseTooLarge,
  invalidJson,
  invalidShape,
  unsupportedVersion,
  invalidEvent,
  invalidTitle,
  invalidDescription,
  invalidDate,
  invalidTime,
  invalidRange,
}

final class AiEventProposalFormatException extends FormatException {
  const AiEventProposalFormatException(this.code, String message)
    : super(message);

  final AiEventProposalErrorCode code;
}
