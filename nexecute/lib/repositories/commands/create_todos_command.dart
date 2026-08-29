const maxTodosPerCreateCommand = 10;
const maxTodoTitleCharacters = 200;

class CreateTodosCommand {
  CreateTodosCommand({
    required this.creationId,
    required this.sourceNoteId,
    required List<String> titles,
    required this.createdAt,
  }) : titles = List.unmodifiable(_validateTitles(titles)) {
    if (creationId.isEmpty ||
        creationId.length > 100 ||
        !_safeId.hasMatch(creationId)) {
      throw ArgumentError.value(
        creationId,
        'creationId',
        'Use 1–100 letters, numbers, underscores, or hyphens.',
      );
    }
    if (sourceNoteId.isEmpty || sourceNoteId.contains('/')) {
      throw ArgumentError.value(
        sourceNoteId,
        'sourceNoteId',
        'A source note ID is required and cannot contain a slash.',
      );
    }
  }

  static final RegExp _safeId = RegExp(r'^[A-Za-z0-9_-]+$');

  final String creationId;
  final String sourceNoteId;
  final List<String> titles;
  final DateTime createdAt;

  String todoIdAt(int index) {
    RangeError.checkValidIndex(index, titles, 'index');
    return 'ai-$creationId-$index';
  }

  static List<String> _validateTitles(List<String> values) {
    if (values.isEmpty || values.length > maxTodosPerCreateCommand) {
      throw ArgumentError.value(
        values,
        'titles',
        'Provide 1–$maxTodosPerCreateCommand task titles.',
      );
    }

    final titles = <String>[];
    final normalizedTitles = <String>{};
    for (final value in values) {
      final title = value.trim();
      if (title.isEmpty ||
          title.length > maxTodoTitleCharacters ||
          title.contains('\n') ||
          title.contains('\r')) {
        throw ArgumentError.value(
          value,
          'titles',
          'Each task title must be one non-empty line of at most '
              '$maxTodoTitleCharacters characters.',
        );
      }
      if (!normalizedTitles.add(title.toLowerCase())) {
        throw ArgumentError.value(
          values,
          'titles',
          'Task titles cannot contain duplicates.',
        );
      }
      titles.add(title);
    }
    return titles;
  }
}
