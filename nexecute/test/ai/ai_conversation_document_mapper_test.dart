import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/repositories/firestore/schema/app_data_schema.dart';

void main() {
  test('conversation metadata round-trips without embedding messages', () {
    final conversation = AiConversation(
      id: 'conversation-1',
      title: 'Planning',
      connectionProfileId: 'home',
      modelId: 'local-model',
      createdAt: DateTime.utc(2026, 8, 29, 10),
      updatedAt: DateTime.utc(2026, 8, 29, 11),
      messages: [
        AiChatMessage(
          id: 'message-1',
          role: AiMessageRole.user,
          content: 'Hello',
          createdAt: DateTime.utc(2026, 8, 29, 10),
        ),
      ],
    );

    final data = AiConversationDocumentMapper.conversationMetadataToMap(
      conversation,
    );
    final restored = AiConversationDocumentMapper.fromMap('conversation-1', {
      ...data,
      'createdAt': Timestamp.fromDate(conversation.createdAt),
      'updatedAt': Timestamp.fromDate(conversation.updatedAt),
    }, messages: conversation.messages);

    expect(data, isNot(contains('messages')));
    expect(data[AppDataSchema.versionField], AppDataSchema.currentVersion);
    expect(restored.title, conversation.title);
    expect(restored.modelId, conversation.modelId);
    expect(restored.messages.single.content, 'Hello');
  });

  test('message mapper preserves partial failure state', () {
    final diagnostic = AiDiagnostic(
      kind: AiDiagnosticKind.dns,
      title: 'Host not found',
      summary: 'The endpoint name could not be resolved.',
      suggestions: const ['Check the endpoint address.'],
    );
    final message = AiChatMessage(
      id: 'assistant-1',
      role: AiMessageRole.assistant,
      content: 'Partial answer',
      createdAt: DateTime.utc(2026, 8, 29, 12),
      status: AiMessageStatus.failed,
      errorMessage: 'Connection lost',
      diagnostic: diagnostic,
    );

    final data = AiConversationDocumentMapper.messageToMap(message);
    final restored = AiConversationDocumentMapper.messageFromMap(
      'assistant-1',
      {...data, 'createdAt': Timestamp.fromDate(message.createdAt)},
    );

    expect(restored.role, AiMessageRole.assistant);
    expect(restored.content, 'Partial answer');
    expect(restored.status, AiMessageStatus.failed);
    expect(restored.errorMessage, 'Connection lost');
    expect(restored.diagnostic?.kind, AiDiagnosticKind.dns);
    expect(restored.diagnostic?.title, 'Host not found');
    expect(restored.diagnostic?.suggestions, ['Check the endpoint address.']);
  });

  test('ignores malformed or unknown stored diagnostics', () {
    final restored = AiConversationDocumentMapper.messageFromMap('message', {
      'diagnostic': {
        'code': 'future_category',
        'title': 'Future failure',
        'summary': 'Not understood by this client.',
      },
    });

    expect(restored.diagnostic, isNull);
  });
}
