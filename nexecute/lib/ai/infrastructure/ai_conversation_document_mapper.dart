import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/ai/domain/ai_chat_message.dart';
import 'package:nexecute/ai/domain/ai_conversation.dart';
import 'package:nexecute/repositories/firestore/schema/app_data_schema.dart';

abstract final class AiConversationDocumentMapper {
  static Map<String, dynamic> conversationMetadataToMap(
    AiConversation conversation,
  ) => AppDataSchema.stamp({
    'id': conversation.id,
    'title': conversation.title,
    'connectionProfileId': conversation.connectionProfileId,
    'modelId': conversation.modelId,
    'createdAt': conversation.createdAt,
    'updatedAt': conversation.updatedAt,
  });

  static AiConversation fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document, {
    List<AiChatMessage> messages = const [],
  }) => fromMap(document.id, document.data() ?? const {}, messages: messages);

  static AiConversation fromMap(
    String id,
    Map<String, dynamic> data, {
    List<AiChatMessage> messages = const [],
  }) {
    final createdAt = _date(data['createdAt']) ?? DateTime.now();
    return AiConversation(
      id: id,
      title: data['title']?.toString() ?? 'New conversation',
      connectionProfileId: data['connectionProfileId']?.toString() ?? '',
      modelId: data['modelId']?.toString() ?? '',
      createdAt: createdAt,
      updatedAt: _date(data['updatedAt']) ?? createdAt,
      messages: messages,
    );
  }

  static Map<String, dynamic> messageToMap(AiChatMessage message) =>
      AppDataSchema.stamp({
        'id': message.id,
        'role': message.role.name,
        'content': message.content,
        'createdAt': message.createdAt,
        'status': message.status.name,
        'errorMessage': message.errorMessage,
        'toolCallId': message.toolCallId,
      });

  static AiChatMessage messageFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) => messageFromMap(document.id, document.data() ?? const {});

  static AiChatMessage messageFromMap(String id, Map<String, dynamic> data) {
    return AiChatMessage(
      id: id,
      role: _enumByName(
        AiMessageRole.values,
        data['role']?.toString(),
        AiMessageRole.assistant,
      ),
      content: data['content']?.toString() ?? '',
      createdAt: _date(data['createdAt']) ?? DateTime.now(),
      status: _enumByName(
        AiMessageStatus.values,
        data['status']?.toString(),
        AiMessageStatus.complete,
      ),
      errorMessage: data['errorMessage']?.toString(),
      toolCallId: data['toolCallId']?.toString(),
    );
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  static DateTime? _date(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime date => date,
    _ => null,
  };
}
