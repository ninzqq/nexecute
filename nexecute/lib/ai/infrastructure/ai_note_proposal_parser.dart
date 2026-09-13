import 'dart:convert';

import 'package:nexecute/ai/domain/ai_note_proposal.dart';

abstract final class AiNoteProposalParser {
  static AiNoteProposal parse(String response) {
    if (response.length > aiMaxNoteProposalResponseCharacters) {
      throw const AiNoteProposalFormatException(
        AiNoteProposalErrorCode.responseTooLarge,
        'The model response was too large to be a note proposal.',
      );
    }
    final text = response.trim();
    final fence = RegExp(
      r'^```(?:json)?\s*(.*?)\s*```$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);
    final Object? decoded;
    try {
      decoded = jsonDecode(fence?.group(1)?.trim() ?? text);
    } on FormatException {
      throw const AiNoteProposalFormatException(
        AiNoteProposalErrorCode.invalidJson,
        'The model did not return valid note-proposal JSON.',
      );
    }
    if (decoded is! Map ||
        decoded.keys.any((key) => key is! String) ||
        decoded.length != 2 ||
        !decoded.containsKey('schemaVersion') ||
        !decoded.containsKey('note')) {
      throw const AiNoteProposalFormatException(
        AiNoteProposalErrorCode.invalidShape,
        'The note proposal contains missing or unsupported fields.',
      );
    }
    if (decoded['schemaVersion'] is! int ||
        decoded['schemaVersion'] != aiNoteProposalSchemaVersion) {
      throw const AiNoteProposalFormatException(
        AiNoteProposalErrorCode.unsupportedVersion,
        'The note-proposal version is not supported.',
      );
    }
    final value = decoded['note'];
    if (value == null) {
      return const AiNoteProposal(
        schemaVersion: aiNoteProposalSchemaVersion,
        note: null,
      );
    }
    if (value is! Map ||
        value.keys.any((key) => key is! String) ||
        value.length != 2 ||
        !value.containsKey('title') ||
        !value.containsKey('body') ||
        value['title'] is! String ||
        value['body'] is! String) {
      throw const AiNoteProposalFormatException(
        AiNoteProposalErrorCode.invalidNote,
        'The proposed note needs only a text title and body.',
      );
    }
    final title = (value['title'] as String).trim();
    final body = (value['body'] as String).trim();
    if (title.isEmpty ||
        title.length > aiMaxProposedNoteTitleCharacters ||
        title.contains('\n') ||
        title.contains('\r') ||
        body.isEmpty ||
        body.length > aiMaxProposedNoteBodyCharacters) {
      throw const AiNoteProposalFormatException(
        AiNoteProposalErrorCode.invalidNote,
        'The proposed note needs a one-line title of at most 300 characters '
        'and a non-empty body of at most 12,000 characters.',
      );
    }
    return AiNoteProposal(
      schemaVersion: aiNoteProposalSchemaVersion,
      note: AiProposedNote(title: title, body: body),
    );
  }
}
