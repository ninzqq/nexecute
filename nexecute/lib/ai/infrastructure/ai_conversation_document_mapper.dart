import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexecute/ai/domain/ai_chat_message.dart';
import 'package:nexecute/ai/domain/ai_citation.dart';
import 'package:nexecute/ai/domain/ai_conversation.dart';
import 'package:nexecute/ai/domain/ai_diagnostic.dart';
import 'package:nexecute/ai/domain/ai_skill_invocation.dart';
import 'package:nexecute/ai/infrastructure/ai_web_search_result_sanitizer.dart';
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
    'activeSkills': [
      for (final skill in conversation.activeSkills)
        {'id': skill.id, 'contentHash': skill.contentHash},
    ],
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
      activeSkills: _skillReferences(data['activeSkills']),
    );
  }

  static Map<String, dynamic> messageToMap(
    AiChatMessage message,
  ) => AppDataSchema.stamp({
    'id': message.id,
    'role': message.role.name,
    'content': message.content,
    'createdAt': message.createdAt,
    if (message.sequence != null) 'sequence': message.sequence,
    'status': message.status.name,
    'errorMessage': message.errorMessage,
    'diagnostic': _diagnosticToMap(message.diagnostic),
    'toolCallId': message.toolCallId,
    'citations': [
      for (final citation in message.citations.take(aiMaxCitationsPerMessage))
        {
          'sourceId': citation.sourceId,
          'title': citation.title,
          'url': citation.url.toString(),
          if (citation.publishedAt != null) 'publishedAt': citation.publishedAt,
        },
    ],
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
      sequence: _sequence(data['sequence']),
      status: _enumByName(
        AiMessageStatus.values,
        data['status']?.toString(),
        AiMessageStatus.complete,
      ),
      errorMessage: data['errorMessage']?.toString(),
      diagnostic: _diagnosticFromMap(data['diagnostic']),
      toolCallId: data['toolCallId']?.toString(),
      citations: _citations(data['citations']),
    );
  }

  static List<AiCitation> _citations(Object? value) {
    if (value is! Iterable) return const [];
    final citations = <AiCitation>[];
    final sourceIds = <String>{};
    for (final item in value.take(aiMaxCitationsPerMessage)) {
      if (item is! Map ||
          item.keys.any(
            (key) =>
                key != 'sourceId' &&
                key != 'title' &&
                key != 'url' &&
                key != 'publishedAt',
          )) {
        continue;
      }
      final sourceId = item['sourceId'];
      final title = item['title'];
      final canonicalUrl = AiWebSearchResultSanitizer.canonicalPublicHttpsUrl(
        item['url'],
      );
      if (sourceId is! String ||
          title is! String ||
          canonicalUrl == null ||
          canonicalUrl.toString() != item['url'] ||
          !sourceIds.add(sourceId)) {
        continue;
      }
      try {
        citations.add(
          AiCitation(
            sourceId: sourceId,
            title: title,
            url: canonicalUrl,
            publishedAt: _date(item['publishedAt']),
          ),
        );
      } on ArgumentError {
        // Ignore malformed synchronized citation metadata.
      }
    }
    return List.unmodifiable(citations);
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

  static int? _sequence(Object? value) {
    if (value is! num || !value.isFinite || value != value.toInt()) return null;
    final sequence = value.toInt();
    return sequence < 0 ? null : sequence;
  }

  static List<AiSkillReference> _skillReferences(Object? value) {
    if (value is! Iterable) return const [];
    final references = <AiSkillReference>[];
    final ids = <String>{};
    for (final item in value) {
      if (item is! Map ||
          item.keys.any((key) => key != 'id' && key != 'contentHash')) {
        continue;
      }
      final id = item['id'];
      final contentHash = item['contentHash'];
      if (id is! String || contentHash is! String || !ids.add(id)) continue;
      try {
        references.add(AiSkillReference(id: id, contentHash: contentHash));
      } on ArgumentError {
        // Ignore corrupt synchronization metadata without loading or persisting
        // any instruction body. Valid references still surface normally.
      }
    }
    return references;
  }

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
