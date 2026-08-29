import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/todo_item.dart';
import 'package:nexecute/repositories/repositories.dart';

void main() {
  test(
    'lists only active tasks inside the authorized bounded result',
    () async {
      final todos = _TodoRepository(
        Stream.fromIterable([
          const DataLoading<List<TodoItem>>(),
          DataReady([
            for (var index = 0; index < 5; index++)
              _todo(id: 'task-$index', title: 'Task $index'),
            _todo(id: 'done', title: 'Completed', isCompleted: true),
          ]),
        ]),
      );
      final service = _service(todos: todos);

      final context = await service.listTasks(
        scope: AiApplicationReadScope(allowActiveTasks: true),
        limit: 2,
      );
      final attachment =
          context.attachments.single as AiActiveTasksContextAttachment;

      expect(attachment.tasks.map((task) => task.title), ['Task 0', 'Task 1']);
      expect(attachment.omittedCount, 3);
      expect(attachment.tasks.every((task) => !task.isCompleted), isTrue);
      expect(todos.watchCount, 1);
    },
  );

  test(
    'rejects unauthorized task reads before touching a repository',
    () async {
      final todos = _TodoRepository(
        Stream.value(const DataEmpty<List<TodoItem>>([])),
      );
      final service = _service(todos: todos);

      await expectLater(
        service.listTasks(scope: AiApplicationReadScope()),
        _throwsReadCode(AiApplicationContextReadErrorCode.unauthorized),
      );
      expect(todos.watchCount, 0);
    },
  );

  test(
    'reads, sorts, and limits events only inside the authorized range',
    () async {
      final authorized = _range(1, 8);
      final requested = _range(2, 3);
      final events = _EventRepository([
        _event(id: 'later', day: 2, hour: 16),
        _event(id: 'earlier', day: 2, hour: 9),
        _event(id: 'outside', day: 5, hour: 9),
      ]);
      final service = _service(events: events);

      final context = await service.eventsForDateRange(
        scope: AiApplicationReadScope(eventRange: authorized),
        range: requested,
        limit: 1,
      );
      final attachment =
          context.attachments.single as AiEventsContextAttachment;

      expect(attachment.events.single.title, 'Event earlier');
      expect(attachment.omittedCount, 1);
      expect(events.watchedRanges, [requested]);

      await expectLater(
        service.eventsForDateRange(
          scope: AiApplicationReadScope(eventRange: authorized),
          range: _range(2, 9),
        ),
        _throwsReadCode(AiApplicationContextReadErrorCode.unauthorized),
      );
      expect(events.watchedRanges, hasLength(1));
    },
  );

  test(
    'searches notes locally but serializes no IDs, tags, or trash',
    () async {
      final notes = _NoteRepository(
        DataReady([
          _note(
            id: 'older-id',
            title: 'Older project',
            text: 'First result',
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
          _note(
            id: 'newer-id',
            title: 'Newer project',
            text: 'Second result',
            updatedAt: DateTime.utc(2026, 1, 3),
          ),
          _note(
            id: 'tag-only-id',
            title: 'Tag match',
            text: 'Third result',
            tags: const ['private-project-tag'],
            updatedAt: DateTime.utc(2026, 1, 2),
          ),
          _note(
            id: 'trashed-id',
            title: 'Trashed project',
            text: 'Do not return',
            trashed: true,
            updatedAt: DateTime.utc(2026, 1, 4),
          ),
        ]),
      );
      final service = _service(notes: notes);

      final result = await service.searchNotes(
        scope: AiApplicationReadScope(allowNoteSearch: true),
        query: '  PROJECT  ',
        limit: 2,
      );
      final attachment =
          result.context.attachments.single as AiSelectedNotesContextAttachment;

      expect(result.sourceNoteIds, ['newer-id', 'tag-only-id']);
      expect(attachment.notes.map((note) => note.title), [
        'Newer project',
        'Tag match',
      ]);
      expect(attachment.omittedCount, 1);
      final encoded = result.context.encode();
      expect(encoded, isNot(contains('newer-id')));
      expect(encoded, isNot(contains('tag-only-id')));
      expect(encoded, isNot(contains('private-project-tag')));
      expect(encoded, isNot(contains('Trashed project')));
      expect(() => result.sourceNoteIds.clear(), throwsUnsupportedError);
    },
  );

  test('gets only a specifically authorized, available note', () async {
    final notes = _NoteRepository(
      DataReady([
        _note(id: 'allowed-note', title: 'Allowed', text: 'Visible'),
        _note(id: 'other-note', title: 'Other', text: 'Hidden'),
        _note(
          id: 'trashed-note',
          title: 'Trash',
          text: 'Hidden',
          trashed: true,
        ),
      ]),
    );
    final service = _service(notes: notes);
    final scope = AiApplicationReadScope(
      allowedNoteIds: const {'allowed-note', 'trashed-note'},
    );

    final context = await service.getNote(scope: scope, noteId: 'allowed-note');
    final attachment =
        context.attachments.single as AiSelectedNotesContextAttachment;
    expect(attachment.notes.single.title, 'Allowed');
    expect(context.encode(), isNot(contains('allowed-note')));

    final readsAfterAllowed = notes.watchCount;
    await expectLater(
      service.getNote(scope: scope, noteId: 'other-note'),
      _throwsReadCode(AiApplicationContextReadErrorCode.unauthorized),
    );
    expect(notes.watchCount, readsAfterAllowed);

    await expectLater(
      service.getNote(scope: scope, noteId: 'trashed-note'),
      _throwsReadCode(AiApplicationContextReadErrorCode.notFound),
    );
  });

  test('validates query, result, identifier, and scope limits', () async {
    final service = _service();
    final searchScope = AiApplicationReadScope(allowNoteSearch: true);

    await expectLater(
      service.searchNotes(scope: searchScope, query: 'x'),
      _throwsReadCode(AiApplicationContextReadErrorCode.invalidArgument),
    );
    await expectLater(
      service.searchNotes(
        scope: searchScope,
        query: List.filled(101, 'x').join(),
      ),
      _throwsReadCode(AiApplicationContextReadErrorCode.invalidArgument),
    );
    await expectLater(
      service.searchNotes(scope: searchScope, query: 'valid', limit: 4),
      _throwsReadCode(AiApplicationContextReadErrorCode.invalidArgument),
    );
    await expectLater(
      service.getNote(
        scope: AiApplicationReadScope(allowedNoteIds: const {'valid-id'}),
        noteId: 'invalid/id',
      ),
      _throwsReadCode(AiApplicationContextReadErrorCode.invalidArgument),
    );
    expect(
      () => AiApplicationReadScope(
        allowedNoteIds: const {'one', 'two', 'three', 'four'},
      ),
      throwsArgumentError,
    );
    expect(
      () => AiApplicationReadScope(allowedNoteIds: const {'invalid/id'}),
      throwsArgumentError,
    );
    expect(
      () => AiApplicationReadScope(eventRange: _range(1, 33)),
      throwsArgumentError,
    );
  });

  test('normalizes unauthenticated, failed, and timed-out streams', () async {
    final unauthenticated = _service(
      todos: _TodoRepository(
        Stream.value(const DataUnauthenticated<List<TodoItem>>()),
      ),
    );
    await expectLater(
      unauthenticated.listTasks(
        scope: AiApplicationReadScope(allowActiveTasks: true),
      ),
      _throwsReadCode(AiApplicationContextReadErrorCode.unauthenticated),
    );

    final failed = _service(
      todos: _TodoRepository(
        Stream.value(DataFailure<List<TodoItem>>(StateError('private detail'))),
      ),
    );
    await expectLater(
      failed.listTasks(scope: AiApplicationReadScope(allowActiveTasks: true)),
      throwsA(
        isA<AiApplicationContextReadException>()
            .having(
              (error) => error.code,
              'code',
              AiApplicationContextReadErrorCode.unavailable,
            )
            .having(
              (error) => error.message,
              'message',
              isNot(contains('private detail')),
            ),
      ),
    );

    final timedOut = _service(
      todos: _TodoRepository(const Stream<DataState<List<TodoItem>>>.empty()),
      readTimeout: const Duration(milliseconds: 5),
    );
    await expectLater(
      timedOut.listTasks(scope: AiApplicationReadScope(allowActiveTasks: true)),
      _throwsReadCode(AiApplicationContextReadErrorCode.unavailable),
    );

    final controller = StreamController<DataState<List<TodoItem>>>();
    addTearDown(controller.close);
    final neverCompletes = _service(
      todos: _TodoRepository(controller.stream),
      readTimeout: const Duration(milliseconds: 5),
    );
    await expectLater(
      neverCompletes.listTasks(
        scope: AiApplicationReadScope(allowActiveTasks: true),
      ),
      _throwsReadCode(AiApplicationContextReadErrorCode.timeout),
    );
  });
}

RepositoryBackedAiApplicationContextReadService _service({
  _TodoRepository? todos,
  _EventRepository? events,
  _NoteRepository? notes,
  Duration readTimeout = const Duration(seconds: 1),
}) => RepositoryBackedAiApplicationContextReadService(
  todoRepository:
      todos ??
      _TodoRepository(Stream.value(const DataEmpty<List<TodoItem>>([]))),
  eventRepository: events ?? _EventRepository(const []),
  noteRepository: notes ?? _NoteRepository(const DataEmpty<List<Quicxec>>([])),
  clock: () => DateTime.utc(2026, 8, 29, 12),
  readTimeout: readTimeout,
);

CalendarQueryRange _range(int startDay, int endDay) => CalendarQueryRange(
  startInclusive: DateTime.utc(2026, 9, startDay),
  endExclusive: DateTime.utc(2026, 9, endDay),
);

TodoItem _todo({
  required String id,
  required String title,
  bool isCompleted = false,
}) => TodoItem(
  id: id,
  title: title,
  isCompleted: isCompleted,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Event _event({required String id, required int day, required int hour}) =>
    Event(
      id: id,
      title: 'Event $id',
      startTime: DateTime.utc(2026, 9, day, hour),
      endTime: DateTime.utc(2026, 9, day, hour + 1),
    );

Quicxec _note({
  required String id,
  required String title,
  required String text,
  DateTime? updatedAt,
  List<String> tags = const [],
  bool trashed = false,
}) => Quicxec(
  id: id,
  title: title,
  text: text,
  tags: tags,
  trashed: trashed,
  created: DateTime.utc(2026),
  updatedAt: updatedAt,
);

Matcher _throwsReadCode(AiApplicationContextReadErrorCode code) => throwsA(
  isA<AiApplicationContextReadException>().having(
    (error) => error.code,
    'code',
    code,
  ),
);

class _TodoRepository implements TodoRepository {
  _TodoRepository(this.states);

  final Stream<DataState<List<TodoItem>>> states;
  var watchCount = 0;

  @override
  Stream<DataState<List<TodoItem>>> watchTodos() {
    watchCount += 1;
    return states;
  }

  @override
  Future<void> addTodo(String title) async {}

  @override
  Future<void> createTodos(CreateTodosCommand command) async {}

  @override
  Future<void> deleteTodo(TodoItem todo) async {}

  @override
  Future<void> restoreTodo(TodoItem todo) async {}

  @override
  Future<void> setCompleted(TodoItem todo, bool isCompleted) async {}

  @override
  Future<void> updateTitle(TodoItem todo, String title) async {}
}

class _EventRepository implements EventRepository {
  _EventRepository(this.events);

  final List<Event> events;
  final watchedRanges = <CalendarQueryRange>[];

  @override
  Stream<DataState<List<Event>>> watchEvents(CalendarQueryRange range) {
    watchedRanges.add(range);
    return Stream.value(DataReady(events));
  }

  @override
  Future<Event> addEvent(Event event) async => event;

  @override
  Future<void> deleteEvent(Event event) async {}

  @override
  Future<List<Event>> searchEvents(String query, {int limit = 50}) async =>
      const [];

  @override
  Future<void> updateEvent(UpdateEventCommand command) async {}
}

class _NoteRepository implements NoteRepository {
  _NoteRepository(this.state);

  final DataState<List<Quicxec>> state;
  var watchCount = 0;

  @override
  Stream<DataState<List<Quicxec>>> watchNotes() {
    watchCount += 1;
    return Stream.value(state);
  }

  @override
  Future<void> addNote(Quicxec note) async {}

  @override
  Future<void> deletePermanently(Quicxec note) async {}

  @override
  Future<void> emptyTrash() async {}

  @override
  Future<void> moveNote(String noteId, String? folderId) async {}

  @override
  Future<void> setChecklistItemChecked(
    Quicxec note,
    String itemId,
    bool isChecked,
  ) async {}

  @override
  Future<void> toggleTrashed(Quicxec note) async {}

  @override
  Future<void> updateNote(UpdateNoteCommand command) async {}
}
