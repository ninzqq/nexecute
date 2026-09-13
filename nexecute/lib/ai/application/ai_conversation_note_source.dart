import 'dart:convert';

import 'package:nexecute/ai/application/ai_request_budget.dart';
import 'package:nexecute/ai/domain/ai_chat_message.dart';
import 'package:nexecute/ai/domain/ai_conversation.dart';

const aiMaxConversationNoteSourceCharacters = 16000;

/// An immutable snapshot of the completed chat text eligible for a note.
/// Message IDs remain local; [payload] is the exact data to preview and later
/// place in the dedicated note-generation request.
final class AiConversationNoteSource {
  AiConversationNoteSource._({
    required this.conversationId,
    required List<AiConversationNoteSourceMessage> availableMessages,
    required this.olderOmittedCount,
    required this.startIndex,
    required this.endIndex,
  }) : availableMessages = List.unmodifiable(availableMessages);

  final String conversationId;
  final List<AiConversationNoteSourceMessage> availableMessages;
  final int olderOmittedCount;
  final int startIndex;
  final int endIndex;

  static AiConversationNoteSource? fromConversation(
    AiConversation? conversation,
  ) {
    if (conversation == null) return null;
    final completed = [
      for (final message in conversation.messages)
        if (message.status == AiMessageStatus.complete &&
            (message.role == AiMessageRole.user ||
                message.role == AiMessageRole.assistant) &&
            message.content.trim().isNotEmpty)
          AiConversationNoteSourceMessage(
            id: message.id,
            role: message.role,
            content: message.content,
            createdAt: message.createdAt,
          ),
    ];
    final firstUser = completed.indexWhere(
      (message) => message.role == AiMessageRole.user,
    );
    if (firstUser < 0) return null;
    final eligible = completed.sublist(firstUser);
    if (!eligible.any((message) => message.role == AiMessageRole.assistant)) {
      return null;
    }

    var start =
        eligible.length > AiRequestBudget.maxHistoryMessages
            ? eligible.length - AiRequestBudget.maxHistoryMessages
            : 0;
    while (start < eligible.length &&
        eligible[start].role != AiMessageRole.user) {
      start++;
    }
    if (start == eligible.length) return null;
    final available = eligible.sublist(start);
    if (!available.any((message) => message.role == AiMessageRole.assistant)) {
      return null;
    }
    return AiConversationNoteSource._(
      conversationId: conversation.id,
      availableMessages: available,
      olderOmittedCount: start + firstUser,
      startIndex: 0,
      endIndex: available.length - 1,
    );
  }

  List<int> get startOptions => List.unmodifiable([
    for (var i = 0; i <= endIndex; i++)
      if (availableMessages[i].role == AiMessageRole.user &&
          availableMessages
              .skip(i + 1)
              .take(endIndex - i)
              .any((message) => message.role == AiMessageRole.assistant))
        i,
  ]);

  List<int> get endOptions => List.unmodifiable([
    for (var i = startIndex + 1; i < availableMessages.length; i++)
      if ((i == availableMessages.length - 1 ||
              availableMessages[i + 1].role == AiMessageRole.user) &&
          availableMessages
              .skip(startIndex + 1)
              .take(i - startIndex)
              .any((message) => message.role == AiMessageRole.assistant))
        i,
  ]);

  AiConversationNoteSource selectRange({
    required int startIndex,
    required int endIndex,
  }) {
    if (startIndex < 0 ||
        endIndex >= availableMessages.length ||
        startIndex >= endIndex ||
        availableMessages[startIndex].role != AiMessageRole.user ||
        (endIndex < availableMessages.length - 1 &&
            availableMessages[endIndex + 1].role != AiMessageRole.user) ||
        !availableMessages
            .skip(startIndex + 1)
            .take(endIndex - startIndex)
            .any((message) => message.role == AiMessageRole.assistant)) {
      throw ArgumentError('Select a contiguous range of completed chat turns.');
    }
    return AiConversationNoteSource._(
      conversationId: conversationId,
      availableMessages: availableMessages,
      olderOmittedCount: olderOmittedCount,
      startIndex: startIndex,
      endIndex: endIndex,
    );
  }

  List<AiConversationNoteSourceMessage> get messages =>
      List.unmodifiable(availableMessages.sublist(startIndex, endIndex + 1));

  int get newerOmittedCount => availableMessages.length - endIndex - 1;
  int get selectedCount => endIndex - startIndex + 1;
  int get totalOmittedCount =>
      olderOmittedCount + startIndex + newerOmittedCount;
  DateTime get firstMessageAt => availableMessages[startIndex].createdAt;
  DateTime get lastMessageAt => availableMessages[endIndex].createdAt;

  String get payload => jsonEncode({
    'messages': [
      for (final message in messages)
        {
          'role': message.role.name,
          'createdAt': message.createdAt.toUtc().toIso8601String(),
          'content': message.content,
        },
    ],
  });

  bool get isWithinLimit =>
      payload.length <= aiMaxConversationNoteSourceCharacters;
}

final class AiConversationNoteSourceMessage {
  const AiConversationNoteSourceMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final AiMessageRole role;
  final String content;
  final DateTime createdAt;
}
