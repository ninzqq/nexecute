import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  test('parses a complete version 1 timed event proposal', () {
    final proposal = AiEventProposalParser.parse(
      jsonEncode({
        'schemaVersion': 1,
        'event': {
          'title': '  Dentist appointment  ',
          'description': '  Annual check-up  ',
          'startDate': '2026-09-14',
          'startTime': '09:30',
          'endDate': '2026-09-14',
          'endTime': '10:15',
          'isAllDay': false,
        },
      }),
    );

    expect(proposal.schemaVersion, aiEventProposalSchemaVersion);
    expect(proposal.event?.title, 'Dentist appointment');
    expect(proposal.event?.description, 'Annual check-up');
    expect(proposal.event?.startDate, '2026-09-14');
    expect(proposal.event?.startTime, '09:30');
    expect(proposal.event?.hasCompleteSchedule, isTrue);
  });

  test('accepts one JSON code fence and no supported event', () {
    final proposal = AiEventProposalParser.parse('''```json
{"schemaVersion":1,"event":null}
```''');

    expect(proposal.event, isNull);
  });

  test('preserves missing scheduling values for trusted review', () {
    final proposal = AiEventProposalParser.parse(
      _proposalJson(
        startDate: '2026-10-01',
        startTime: null,
        endDate: null,
        endTime: null,
        isAllDay: null,
      ),
    );

    expect(proposal.event?.startDate, '2026-10-01');
    expect(proposal.event?.startTime, isNull);
    expect(proposal.event?.isAllDay, isNull);
    expect(proposal.event?.hasCompleteSchedule, isFalse);
  });

  test('accepts a complete all-day range without wall-clock times', () {
    final proposal = AiEventProposalParser.parse(
      _proposalJson(
        startDate: '2026-12-24',
        startTime: null,
        endDate: '2026-12-26',
        endTime: null,
        isAllDay: true,
      ),
    );

    expect(proposal.event?.hasCompleteSchedule, isTrue);
  });

  test('accepts an explicit overnight timed range', () {
    final proposal = AiEventProposalParser.parse(
      _proposalJson(
        startDate: '2026-09-03',
        startTime: '23:00',
        endDate: '2026-09-04',
        endTime: '01:00',
        isAllDay: false,
      ),
    );

    expect(proposal.event?.startDate, '2026-09-03');
    expect(proposal.event?.endDate, '2026-09-04');
    expect(proposal.event?.hasCompleteSchedule, isTrue);
  });

  test('rejects prose, unknown fields, and unsupported versions', () {
    expect(
      () =>
          AiEventProposalParser.parse('Here: {"schemaVersion":1,"event":null}'),
      _throwsCode(AiEventProposalErrorCode.invalidJson),
    );
    expect(
      () => AiEventProposalParser.parse(
        '{"schemaVersion":1,"event":null,"write":true}',
      ),
      _throwsCode(AiEventProposalErrorCode.invalidShape),
    );
    expect(
      () => AiEventProposalParser.parse('{"schemaVersion":2,"event":null}'),
      _throwsCode(AiEventProposalErrorCode.unsupportedVersion),
    );
  });

  test('rejects missing event fields and invalid text fields', () {
    expect(
      () => AiEventProposalParser.parse(
        jsonEncode({
          'schemaVersion': 1,
          'event': {'title': 'Incomplete'},
        }),
      ),
      _throwsCode(AiEventProposalErrorCode.invalidEvent),
    );
    expect(
      () => AiEventProposalParser.parse(_proposalJson(title: 'First\nSecond')),
      _throwsCode(AiEventProposalErrorCode.invalidTitle),
    );
    expect(
      () => AiEventProposalParser.parse(
        _proposalJson(
          description:
              List.filled(
                aiMaxProposedEventDescriptionCharacters + 1,
                'x',
              ).join(),
        ),
      ),
      _throwsCode(AiEventProposalErrorCode.invalidDescription),
    );
  });

  test('rejects impossible dates and malformed times', () {
    expect(
      () => AiEventProposalParser.parse(_proposalJson(startDate: '2026-02-30')),
      _throwsCode(AiEventProposalErrorCode.invalidDate),
    );
    expect(
      () => AiEventProposalParser.parse(_proposalJson(startTime: '24:00')),
      _throwsCode(AiEventProposalErrorCode.invalidTime),
    );
  });

  test('rejects invalid and excessive ranges', () {
    expect(
      () => AiEventProposalParser.parse(
        _proposalJson(
          startDate: '2026-09-14',
          startTime: '10:00',
          endDate: '2026-09-14',
          endTime: '09:00',
          isAllDay: false,
        ),
      ),
      _throwsCode(AiEventProposalErrorCode.invalidRange),
    );
    expect(
      () => AiEventProposalParser.parse(
        _proposalJson(
          startDate: '2026-09-14',
          startTime: '23:00',
          endDate: '2026-09-13',
          endTime: '01:00',
          isAllDay: false,
        ),
      ),
      _throwsCode(AiEventProposalErrorCode.invalidRange),
    );
    expect(
      () => AiEventProposalParser.parse(
        _proposalJson(
          startDate: '2026-01-01',
          startTime: null,
          endDate: '2028-01-01',
          endTime: null,
          isAllDay: true,
        ),
      ),
      _throwsCode(AiEventProposalErrorCode.invalidRange),
    );
    expect(
      () => AiEventProposalParser.parse(
        _proposalJson(startTime: '10:00', endTime: null, isAllDay: true),
      ),
      _throwsCode(AiEventProposalErrorCode.invalidTime),
    );
  });

  test('rejects oversized output before decoding it', () {
    expect(
      () => AiEventProposalParser.parse(
        List.filled(aiMaxEventProposalResponseCharacters + 1, 'x').join(),
      ),
      _throwsCode(AiEventProposalErrorCode.responseTooLarge),
    );
  });
}

String _proposalJson({
  String title = 'Planning session',
  String description = '',
  String? startDate = '2026-09-14',
  String? startTime = '09:00',
  String? endDate = '2026-09-14',
  String? endTime = '10:00',
  bool? isAllDay = false,
}) {
  return jsonEncode({
    'schemaVersion': 1,
    'event': {
      'title': title,
      'description': description,
      'startDate': startDate,
      'startTime': startTime,
      'endDate': endDate,
      'endTime': endTime,
      'isAllDay': isAllDay,
    },
  });
}

Matcher _throwsCode(AiEventProposalErrorCode code) {
  return throwsA(
    isA<AiEventProposalFormatException>().having(
      (error) => error.code,
      'code',
      code,
    ),
  );
}
