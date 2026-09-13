import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  test('parses a bounded note and a deliberate no-proposal response', () {
    final proposal = AiNoteProposalParser.parse(
      jsonEncode({
        'schemaVersion': 1,
        'note': {
          'title': '  Launch plan  ',
          'body': '  Decision: launch in October.\nOpen: budget.  ',
        },
      }),
    );
    expect(proposal.note?.title, 'Launch plan');
    expect(proposal.note?.body, 'Decision: launch in October.\nOpen: budget.');
    expect(
      AiNoteProposalParser.parse(
        '```json\n{"schemaVersion":1,"note":null}\n```',
      ).note,
      isNull,
    );
  });

  test('rejects prose, unsupported versions, and extra fields', () {
    expect(
      () => AiNoteProposalParser.parse(
        'Here is a note: {"schemaVersion":1,"note":null}',
      ),
      _throwsCode(AiNoteProposalErrorCode.invalidJson),
    );
    expect(
      () => AiNoteProposalParser.parse('{"schemaVersion":2,"note":null}'),
      _throwsCode(AiNoteProposalErrorCode.unsupportedVersion),
    );
    expect(
      () => AiNoteProposalParser.parse(
        '{"schemaVersion":1,"note":null,"action":"write"}',
      ),
      _throwsCode(AiNoteProposalErrorCode.invalidShape),
    );
    expect(
      () => AiNoteProposalParser.parse(
        '{"schemaVersion":1,"note":{"title":"A","body":"B","id":"secret"}}',
      ),
      _throwsCode(AiNoteProposalErrorCode.invalidNote),
    );
  });

  test('rejects empty, multiline, and oversized content', () {
    for (final note in [
      {'title': '', 'body': 'Body'},
      {'title': 'First\nSecond', 'body': 'Body'},
      {'title': 'A', 'body': ' '},
      {'title': 'A' * (aiMaxProposedNoteTitleCharacters + 1), 'body': 'Body'},
      {'title': 'A', 'body': 'B' * (aiMaxProposedNoteBodyCharacters + 1)},
    ]) {
      expect(
        () => AiNoteProposalParser.parse(
          jsonEncode({'schemaVersion': 1, 'note': note}),
        ),
        _throwsCode(AiNoteProposalErrorCode.invalidNote),
      );
    }
    expect(
      () => AiNoteProposalParser.parse(
        'x' * (aiMaxNoteProposalResponseCharacters + 1),
      ),
      _throwsCode(AiNoteProposalErrorCode.responseTooLarge),
    );
  });
}

Matcher _throwsCode(AiNoteProposalErrorCode code) => throwsA(
  isA<AiNoteProposalFormatException>().having(
    (error) => error.code,
    'code',
    code,
  ),
);
