import 'package:nexecute/models/quicxec.dart';

const maxCreateConversationNoteTitleCharacters = 300;
const maxCreateConversationNoteBodyCharacters = 12000;
const maxCreateConversationNoteSourceMessages = 24;

class CreateConversationNoteCommand {
  CreateConversationNoteCommand({
    required this.creationId,
    required this.sourceConversationId,
    required List<String> sourceMessageIds,
    required String title,
    required String body,
    required this.createdAt,
  }) : sourceMessageIds = List.unmodifiable(
         _validateMessageIds(sourceMessageIds),
       ),
       title = _validateTitle(title),
       body = _validateBody(body) {
    _validateId(creationId, 'creationId', maxLength: 100);
    _validateId(sourceConversationId, 'sourceConversationId');
  }

  static final RegExp _safeCreationId = RegExp(r'^[A-Za-z0-9_-]+$');

  final String creationId;
  final String sourceConversationId;
  final List<String> sourceMessageIds;
  final String title;
  final String body;
  final DateTime createdAt;

  String get noteId => 'ai-note-$creationId';

  Quicxec toNote() =>
      Quicxec(id: noteId, title: title, text: body, created: createdAt);

  static void _validateId(String value, String name, {int maxLength = 1500}) {
    if (value.isEmpty ||
        value.length > maxLength ||
        value.contains('/') ||
        (name == 'creationId' && !_safeCreationId.hasMatch(value))) {
      throw ArgumentError.value(
        value,
        name,
        'Use a valid source or creation ID.',
      );
    }
  }

  static List<String> _validateMessageIds(List<String> values) {
    if (values.length < 2 ||
        values.length > maxCreateConversationNoteSourceMessages) {
      throw ArgumentError.value(
        values,
        'sourceMessageIds',
        'Use 2–$maxCreateConversationNoteSourceMessages source messages.',
      );
    }
    final seen = <String>{};
    for (final value in values) {
      _validateId(value, 'sourceMessageId');
      if (!seen.add(value)) {
        throw ArgumentError.value(
          values,
          'sourceMessageIds',
          'Source message IDs must be unique.',
        );
      }
    }
    return values;
  }

  static String _validateTitle(String value) {
    final title = value.trim();
    if (title.isEmpty ||
        title.length > maxCreateConversationNoteTitleCharacters ||
        title.contains('\n') ||
        title.contains('\r')) {
      throw ArgumentError.value(
        value,
        'title',
        'Use one non-empty line of at most '
            '$maxCreateConversationNoteTitleCharacters characters.',
      );
    }
    return title;
  }

  static String _validateBody(String value) {
    final body = value.trim();
    if (body.isEmpty || body.length > maxCreateConversationNoteBodyCharacters) {
      throw ArgumentError.value(
        value,
        'body',
        'Use a non-empty body of at most '
            '$maxCreateConversationNoteBodyCharacters characters.',
      );
    }
    return body;
  }
}
