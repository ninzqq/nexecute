import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/ai/domain/ai_chat_message.dart';
import 'package:nexecute/ai/domain/ai_conversation.dart';
import 'package:nexecute/ai/domain/ai_diagnostic.dart';
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
        'diagnostic': _diagnosticToMap(message.diagnostic),
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
      diagnostic: _diagnosticFromMap(data['diagnostic']),
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

  static Map<String, Object?>? _diagnosticToMap(AiDiagnostic? diagnostic) {
    if (diagnostic == null) return null;
    return {
      'code': diagnostic.code,
      'title': diagnostic.title,
      'summary': diagnostic.summary,
      'suggestions': diagnostic.suggestions,
    };
  }

  static AiDiagnostic? _diagnosticFromMap(Object? value) {
    if (value is! Map) return null;
    final kind = AiDiagnosticKind.fromCode(value['code']?.toString());
    final title = value['title']?.toString().trim() ?? '';
    final summary = value['summary']?.toString().trim() ?? '';
    final rawSuggestions = value['suggestions'];
    if (kind == null || title.isEmpty || summary.isEmpty) return null;
    final suggestions =
        rawSuggestions is Iterable
            ? rawSuggestions
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList()
            : const <String>[];
    return AiDiagnostic(
      kind: kind,
      title: title,
      summary: summary,
      suggestions: suggestions,
    );
  }
}
