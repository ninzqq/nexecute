import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  test('parses a valid immutable version 1 proposal', () {
    final proposal = AiTaskProposalParser.parse(
      jsonEncode({
        'schemaVersion': 1,
        'tasks': [
          {'title': '  Buy oat milk  '},
          {'title': 'Book the dentist'},
        ],
      }),
    );

    expect(proposal.schemaVersion, aiTaskProposalSchemaVersion);
    expect(proposal.tasks.map((task) => task.title), [
      'Buy oat milk',
      'Book the dentist',
    ]);
    expect(() => proposal.tasks.clear(), throwsUnsupportedError);
  });

  test('accepts one JSON code fence and an empty task list', () {
    final proposal = AiTaskProposalParser.parse('''```json
{"schemaVersion":1,"tasks":[]}
```''');

    expect(proposal.tasks, isEmpty);
  });

  test('rejects prose around otherwise valid JSON', () {
    expect(
      () => AiTaskProposalParser.parse(
        'Here you go: {"schemaVersion":1,"tasks":[]}',
      ),
      _throwsCode(AiTaskProposalErrorCode.invalidJson),
    );
  });

  test('rejects unknown fields and schema versions', () {
    expect(
      () => AiTaskProposalParser.parse(
        '{"schemaVersion":1,"tasks":[],"explanation":"done"}',
      ),
      _throwsCode(AiTaskProposalErrorCode.invalidShape),
    );
    expect(
      () => AiTaskProposalParser.parse('{"schemaVersion":2,"tasks":[]}'),
      _throwsCode(AiTaskProposalErrorCode.unsupportedVersion),
    );
  });

  test('rejects too many, malformed, multiline, and duplicate tasks', () {
    expect(
      () => AiTaskProposalParser.parse(
        jsonEncode({
          'schemaVersion': 1,
          'tasks': List.generate(
            aiMaxProposedTasks + 1,
            (index) => {'title': 'Task $index'},
          ),
        }),
      ),
      _throwsCode(AiTaskProposalErrorCode.tooManyTasks),
    );
    expect(
      () => AiTaskProposalParser.parse(
        '{"schemaVersion":1,"tasks":[{"title":"First\\nSecond"}]}',
      ),
      _throwsCode(AiTaskProposalErrorCode.invalidTask),
    );
    expect(
      () => AiTaskProposalParser.parse(
        '{"schemaVersion":1,"tasks":[{"title":"Call Sam"},{"title":" call sam "}]}',
      ),
      _throwsCode(AiTaskProposalErrorCode.duplicateTask),
    );
  });

  test('rejects oversized output before decoding it', () {
    expect(
      () => AiTaskProposalParser.parse(
        List.filled(aiMaxTaskProposalResponseCharacters + 1, 'x').join(),
      ),
      _throwsCode(AiTaskProposalErrorCode.responseTooLarge),
    );
  });
}

Matcher _throwsCode(AiTaskProposalErrorCode code) {
  return throwsA(
    isA<AiTaskProposalFormatException>().having(
      (error) => error.code,
      'code',
      code,
    ),
  );
}
