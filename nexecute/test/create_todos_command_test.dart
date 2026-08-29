import 'package:nexecute/repositories/todo_repository.dart';
import 'package:test/test.dart';

void main() {
  test('normalizes titles and creates stable task IDs', () {
    final createdAt = DateTime.utc(2026, 8, 29, 12);
    final command = CreateTodosCommand(
      creationId: 'proposal_123',
      sourceNoteId: 'note-1',
      titles: ['  Buy coffee  ', 'Call Sam'],
      createdAt: createdAt,
    );

    expect(command.titles, ['Buy coffee', 'Call Sam']);
    expect(command.todoIdAt(0), 'ai-proposal_123-0');
    expect(command.todoIdAt(1), 'ai-proposal_123-1');
    expect(command.createdAt, createdAt);
    expect(() => command.titles.add('Not allowed'), throwsUnsupportedError);
  });

  test('rejects invalid creation data before repository writes', () {
    expect(
      () => CreateTodosCommand(
        creationId: 'contains/slash',
        sourceNoteId: 'note-1',
        titles: const ['Buy coffee'],
        createdAt: DateTime.utc(2026),
      ),
      throwsArgumentError,
    );
    expect(
      () => CreateTodosCommand(
        creationId: 'proposal-1',
        sourceNoteId: 'note-1',
        titles: const ['Buy coffee', ' buy coffee '],
        createdAt: DateTime.utc(2026),
      ),
      throwsArgumentError,
    );
    expect(
      () => CreateTodosCommand(
        creationId: 'proposal-1',
        sourceNoteId: 'note-1',
        titles: const [],
        createdAt: DateTime.utc(2026),
      ),
      throwsArgumentError,
    );
  });
}
