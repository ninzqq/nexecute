import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  final start = DateTime.utc(2026, 9, 13, 10);

  AiChatMessage message(
    int index,
    AiMessageRole role,
    String content, {
    AiMessageStatus status = AiMessageStatus.complete,
  }) => AiChatMessage(
    id: 'message-$index',
    role: role,
    content: content,
    createdAt: start.add(Duration(minutes: index)),
    sequence: index,
    status: status,
  );

  AiConversation conversation(List<AiChatMessage> messages) => AiConversation(
    id: 'conversation-1',
    title: 'Project plan',
    connectionProfileId: 'profile-1',
    modelId: 'model-1',
    createdAt: start,
    updatedAt: start,
    messages: messages,
  );

  test(
    'includes only completed user and assistant text in ordered payload',
    () {
      final source =
          AiConversationNoteSource.fromConversation(
            conversation([
              message(0, AiMessageRole.assistant, 'Orphaned answer'),
              message(1, AiMessageRole.user, 'Plan the launch.'),
              message(2, AiMessageRole.tool, 'Private tool result'),
              message(3, AiMessageRole.assistant, 'Decide the date.'),
              message(
                4,
                AiMessageRole.assistant,
                'Failed text',
                status: AiMessageStatus.failed,
              ),
              message(5, AiMessageRole.user, 'And budget?'),
              message(
                6,
                AiMessageRole.assistant,
                'Not finished',
                status: AiMessageStatus.streaming,
              ),
            ]),
          )!;

      expect(source.messages.map((m) => m.id), [
        'message-1',
        'message-3',
        'message-5',
      ]);
      expect(source.olderOmittedCount, 1);
      expect(source.totalOmittedCount, 1);
      expect(jsonDecode(source.payload), {
        'messages': [
          {
            'role': 'user',
            'createdAt': '2026-09-13T10:01:00.000Z',
            'content': 'Plan the launch.',
          },
          {
            'role': 'assistant',
            'createdAt': '2026-09-13T10:03:00.000Z',
            'content': 'Decide the date.',
          },
          {
            'role': 'user',
            'createdAt': '2026-09-13T10:05:00.000Z',
            'content': 'And budget?',
          },
        ],
      });
      expect(source.payload, isNot(contains('Private tool result')));
      expect(source.payload, isNot(contains('Failed text')));
    },
  );

  test('uses newest 24 messages at a user turn and can narrow whole turns', () {
    final messages = [
      for (var i = 0; i < 30; i++)
        message(
          i,
          i.isEven ? AiMessageRole.user : AiMessageRole.assistant,
          'Text $i',
        ),
    ];
    final source =
        AiConversationNoteSource.fromConversation(conversation(messages))!;
    expect(source.messages.first.id, 'message-6');
    expect(source.messages.last.id, 'message-29');
    expect(source.olderOmittedCount, 6);
    expect(source.selectedCount, 24);

    final narrowed = source.selectRange(startIndex: 2, endIndex: 5);
    expect(narrowed.messages.map((m) => m.id), [
      'message-8',
      'message-9',
      'message-10',
      'message-11',
    ]);
    expect(narrowed.totalOmittedCount, 26);
    expect(source.selectedCount, 24); // The original snapshot is unchanged.
    expect(
      () => source.selectRange(startIndex: 1, endIndex: 5),
      throwsArgumentError,
    );
    expect(
      () => source.selectRange(startIndex: 2, endIndex: 4),
      throwsArgumentError,
    );
  });

  test('rejects oversized source without truncating it', () {
    final source =
        AiConversationNoteSource.fromConversation(
          conversation([
            message(0, AiMessageRole.user, 'x' * 16000),
            message(1, AiMessageRole.assistant, 'A response'),
            message(2, AiMessageRole.user, 'Short question'),
            message(3, AiMessageRole.assistant, 'Short answer'),
          ]),
        )!;
    expect(source.isWithinLimit, isFalse);
    expect(source.payload, contains('x' * 16000));
    expect(
      source.selectRange(startIndex: 2, endIndex: 3).isWithinLimit,
      isTrue,
    );
  });

  test('requires a completed user and assistant exchange', () {
    expect(AiConversationNoteSource.fromConversation(conversation([])), isNull);
    expect(
      AiConversationNoteSource.fromConversation(
        conversation([message(0, AiMessageRole.user, 'Question')]),
      ),
      isNull,
    );
    expect(
      AiConversationNoteSource.fromConversation(
        conversation([
          message(0, AiMessageRole.user, 'Question'),
          message(
            1,
            AiMessageRole.assistant,
            'Failed',
            status: AiMessageStatus.failed,
          ),
        ]),
      ),
      isNull,
    );
  });
}
