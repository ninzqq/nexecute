const aiNoteProposalSchemaVersion = 1;
const aiMaxProposedNoteTitleCharacters = 300;
const aiMaxProposedNoteBodyCharacters = 12000;
const aiMaxNoteProposalResponseCharacters = 32000;

final class AiProposedNote {
  const AiProposedNote({required this.title, required this.body});

  final String title;
  final String body;
}

final class AiNoteProposal {
  const AiNoteProposal({required this.schemaVersion, required this.note});

  final int schemaVersion;
  final AiProposedNote? note;
}

enum AiNoteProposalErrorCode {
  responseTooLarge,
  invalidJson,
  invalidShape,
  unsupportedVersion,
  invalidNote,
}

final class AiNoteProposalFormatException extends FormatException {
  const AiNoteProposalFormatException(this.code, String message)
    : super(message);

  final AiNoteProposalErrorCode code;
}
