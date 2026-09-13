import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/repositories/note_repository.dart';

void main() {
  final now = DateTime.utc(2026, 9, 13, 12);

  CreateConversationNoteCommand command({
    String creationId = 'creation-1',
    String sourceConversationId = 'conversation-1',
    List<String> sourceMessageIds = const ['user-1', 'assistant-1'],
    String title = '  Project plan  ',
    String body = '  Decide a date and budget.  ',
  }) => CreateConversationNoteCommand(
    creationId: creationId,
    sourceConversationId: sourceConversationId,
    sourceMessageIds: sourceMessageIds,
    title: title,
    body: body,
    createdAt: now,
  );

  test(
    'freezes validated content, source references, and deterministic ID',
    () {
      final mutableIds = ['user-1', 'assistant-1'];
      final value = command(sourceMessageIds: mutableIds);
      mutableIds.add('later-message');

      expect(value.noteId, 'ai-note-creation-1');
      expect(value.title, 'Project plan');
      expect(value.body, 'Decide a date and budget.');
      expect(value.sourceMessageIds, ['user-1', 'assistant-1']);
      expect(
        () => value.sourceMessageIds.add('another'),
        throwsUnsupportedError,
      );
      final note = value.toNote();
      expect(note.id, value.noteId);
      expect(note.title, value.title);
      expect(note.text, value.body);
      expect(note.created, now);
    },
  );

  test('rejects invalid values before repository access', () {
    expect(() => command(creationId: 'bad/id'), throwsArgumentError);
    expect(() => command(sourceConversationId: 'bad/id'), throwsArgumentError);
    expect(() => command(sourceMessageIds: ['one']), throwsArgumentError);
    expect(
      () => command(sourceMessageIds: ['one', 'one']),
      throwsArgumentError,
    );
    expect(
      () => command(sourceMessageIds: ['one', 'bad/id']),
      throwsArgumentError,
    );
    expect(() => command(title: ' '), throwsArgumentError);
    expect(() => command(title: 'First\nSecond'), throwsArgumentError);
    expect(
      () =>
          command(title: 'x' * (maxCreateConversationNoteTitleCharacters + 1)),
      throwsArgumentError,
    );
    expect(() => command(body: ' '), throwsArgumentError);
    expect(
      () => command(body: 'x' * (maxCreateConversationNoteBodyCharacters + 1)),
      throwsArgumentError,
    );
  });
}
