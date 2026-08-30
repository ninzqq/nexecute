import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  late AiConnectionProfile profile;

  setUp(() {
    profile = AiConnectionProfile(
      id: 'home',
      name: 'Home AI',
      protocol: AiProtocol.openAiCompatibleChat,
      baseUrl: Uri.parse('https://ai.example.test/v1'),
      modelId: 'tool-model',
      capabilityOverrides: const {AiCapability.tools: true},
    );
  });

  test('executes an authorized read and continues to final text', () async {
    late FakeAiAssistantRepository repository;
    repository = FakeAiAssistantRepository(
      responseStreamBuilder: (_) {
        if (repository.startedRequests.length == 1) {
          return Stream.fromIterable([
            AiToolCallRequested(
              id: 'call-1',
              name: AiReadToolNames.listTasks,
              arguments: const {'limit': 2},
            ),
            AiToolCallRequested(
              id: 'call-2',
              name: AiReadToolNames.eventsForDateRange,
              arguments: const {
                'startInclusive': '2026-08-30T00:00:00Z',
                'endExclusive': '2026-08-31T00:00:00Z',
                'limit': 10,
              },
            ),
            const AiResponseCompleted(finishReason: 'tool_calls'),
          ]);
        }
        return Stream.fromIterable(const [
          AiTextDelta('Start with the roadmap.'),
          AiResponseCompleted(finishReason: 'stop'),
        ]);
      },
    );
    final readService = FakeAiApplicationContextReadService();
    readService.tasksContext = _taskContext('Review Step 9E');
    readService.eventsContext = AiApplicationContextEnvelope(
      generatedAt: DateTime.utc(2026, 8, 30),
      attachments: [
        AiEventsContextAttachment(
          range: AiEventContextRange(
            startInclusive: DateTime.utc(2026, 8, 30),
            endExclusive: DateTime.utc(2026, 8, 31),
          ),
          events: const [],
          omittedCount: 0,
        ),
      ],
    );
    final authorization = AiReadToolAuthorization(
      allowActiveTasks: true,
      eventRange: AiEventContextRange(
        startInclusive: DateTime.utc(2026, 8, 30),
        endExclusive: DateTime.utc(2026, 8, 31),
      ),
    );
    final coordinator = AiReadToolCoordinator(
      assistantRepository: repository,
      readService: readService,
    );
    final handle = await coordinator.startResponse(
      _request(profile, authorization),
      scope: AiReadToolExecutionScope(authorization: authorization),
    );

    final events = await handle.events.toList();

    expect(readService.taskReadCount, 1);
    expect(readService.eventReadCount, 1);
    expect(repository.startedRequests, hasLength(2));
    expect(events.whereType<AiToolCallRequested>(), isEmpty);
    expect(
      events.whereType<AiTextDelta>().single.text,
      'Start with the roadmap.',
    );
    expect(events.last, isA<AiResponseCompleted>());
    final continuation = repository.startedRequests.last.continuationMessages;
    expect(continuation, hasLength(3));
    expect(continuation.first, isA<AiAssistantToolCallMessage>());
    final results = continuation.whereType<AiToolResultMessage>().toList();
    expect(results.every((result) => !result.isError), isTrue);
    expect(
      results.every(
        (result) =>
            result.result['dataClassification'] ==
            aiApplicationContextDataClassification,
      ),
      isTrue,
    );
    expect(results.first.result.toString(), contains('Review Step 9E'));
  });

  test(
    'returns safe errors for unknown, malformed, and unauthorized calls',
    () async {
      late FakeAiAssistantRepository repository;
      repository = FakeAiAssistantRepository(
        responseStreamBuilder: (_) {
          if (repository.startedRequests.length == 1) {
            return Stream.fromIterable([
              AiToolCallRequested(
                id: 'unknown',
                name: 'deleteEverything',
                arguments: const {},
              ),
              AiToolCallRequested(
                id: 'malformed',
                name: AiReadToolNames.listTasks,
                arguments: const {'limit': 1, 'extra': true},
              ),
              AiToolCallRequested(
                id: 'unauthorized',
                name: AiReadToolNames.eventsForDateRange,
                arguments: const {
                  'startInclusive': '2026-08-30T00:00:00Z',
                  'endExclusive': '2026-08-31T00:00:00Z',
                  'limit': 5,
                },
              ),
              const AiResponseCompleted(finishReason: 'tool_calls'),
            ]);
          }
          return Stream.fromIterable(const [
            AiTextDelta('I could not access anything outside the scope.'),
            AiResponseCompleted(),
          ]);
        },
      );
      final readService = FakeAiApplicationContextReadService();
      final authorization = AiReadToolAuthorization(allowActiveTasks: true);
      final coordinator = AiReadToolCoordinator(
        assistantRepository: repository,
        readService: readService,
      );
      final handle = await coordinator.startResponse(
        _request(profile, authorization),
        scope: AiReadToolExecutionScope(authorization: authorization),
      );

      final events = await handle.events.toList();

      expect(events.last, isA<AiResponseCompleted>());
      expect(readService.taskReadCount, 0);
      expect(readService.eventReadCount, 0);
      final results =
          repository.startedRequests.last.continuationMessages
              .whereType<AiToolResultMessage>()
              .toList();
      expect(results.map((result) => result.result['code']), [
        'unknown_tool',
        'invalid_arguments',
        'unauthorized',
      ]);
      expect(results.every((result) => result.isError), isTrue);
      expect(results.toString(), isNot(contains('deleteEverything')));
    },
  );

  test(
    'search results gain opaque references for a later getNote call',
    () async {
      late FakeAiAssistantRepository repository;
      repository = FakeAiAssistantRepository(
        responseStreamBuilder: (_) {
          return switch (repository.startedRequests.length) {
            1 => Stream.fromIterable([
              AiToolCallRequested(
                id: 'search',
                name: AiReadToolNames.searchNotes,
                arguments: const {'query': 'roadmap', 'limit': 1},
              ),
              const AiResponseCompleted(finishReason: 'tool_calls'),
            ]),
            2 => Stream.fromIterable([
              AiToolCallRequested(
                id: 'read',
                name: AiReadToolNames.getNote,
                arguments: const {'noteReference': 'note_ref'},
              ),
              const AiResponseCompleted(finishReason: 'tool_calls'),
            ]),
            _ => Stream.fromIterable(const [
              AiTextDelta('The note is summarized.'),
              AiResponseCompleted(),
            ]),
          };
        },
      );
      final readService = FakeAiApplicationContextReadService();
      readService.noteSearchResult = AiNoteSearchContextResult(
        context: _noteContext('Roadmap', 'Implement bounded tools'),
        sourceNoteIds: const ['internal-note-id'],
      );
      readService.noteContext = _noteContext(
        'Roadmap',
        'Implement bounded tools',
      );
      final authorization = AiReadToolAuthorization(allowNoteSearch: true);
      final coordinator = AiReadToolCoordinator(
        assistantRepository: repository,
        readService: readService,
        opaqueReferenceFactory: () => 'note_ref',
      );
      final handle = await coordinator.startResponse(
        _request(profile, authorization),
        scope: AiReadToolExecutionScope(authorization: authorization),
      );

      final events = await handle.events.toList();

      expect(
        events.whereType<AiTextDelta>().single.text,
        'The note is summarized.',
      );
      expect(readService.noteSearchCount, 1);
      expect(readService.noteReadCount, 1);
      expect(repository.startedRequests, hasLength(3));
      expect(
        repository.startedRequests[1].toolDefinitions.map((tool) => tool.name),
        contains(AiReadToolNames.getNote),
      );
      final searchResult =
          repository.startedRequests[1].continuationMessages
              .whereType<AiToolResultMessage>()
              .single;
      expect(searchResult.result['noteReferences'], ['note_ref']);
      expect(
        searchResult.result.toString(),
        isNot(contains('internal-note-id')),
      );
    },
  );

  test('rejects excessive calls and continuation rounds', () async {
    late FakeAiAssistantRepository excessiveRepository;
    excessiveRepository = FakeAiAssistantRepository(
      responseStreamBuilder:
          (_) => Stream.fromIterable([
            for (var index = 0; index < 5; index++)
              AiToolCallRequested(
                id: 'call-$index',
                name: AiReadToolNames.listTasks,
                arguments: const {'limit': 1},
              ),
            const AiResponseCompleted(finishReason: 'tool_calls'),
          ]),
    );
    final excessiveReads = FakeAiApplicationContextReadService();
    final authorization = AiReadToolAuthorization(allowActiveTasks: true);
    final excessiveCoordinator = AiReadToolCoordinator(
      assistantRepository: excessiveRepository,
      readService: excessiveReads,
    );
    final excessiveHandle = await excessiveCoordinator.startResponse(
      _request(profile, authorization),
      scope: AiReadToolExecutionScope(authorization: authorization),
    );

    final excessiveEvents = await excessiveHandle.events.toList();

    expect(
      (excessiveEvents.single as AiResponseFailed).code,
      'tool_call_limit',
    );
    expect(excessiveReads.taskReadCount, 0);

    late FakeAiAssistantRepository loopingRepository;
    loopingRepository = FakeAiAssistantRepository(
      responseStreamBuilder:
          (_) => Stream.fromIterable([
            AiToolCallRequested(
              id: 'call-${loopingRepository.startedRequests.length}',
              name: AiReadToolNames.listTasks,
              arguments: const {'limit': 1},
            ),
            const AiResponseCompleted(finishReason: 'tool_calls'),
          ]),
    );
    final loopingReads = FakeAiApplicationContextReadService();
    final loopingCoordinator = AiReadToolCoordinator(
      assistantRepository: loopingRepository,
      readService: loopingReads,
    );
    final loopingHandle = await loopingCoordinator.startResponse(
      _request(profile, authorization),
      scope: AiReadToolExecutionScope(authorization: authorization),
    );

    final loopingEvents = await loopingHandle.events.toList();

    expect((loopingEvents.single as AiResponseFailed).code, 'tool_round_limit');
    expect(loopingRepository.startedRequests, hasLength(4));
    expect(loopingReads.taskReadCount, 3);
  });

  test('bounds cumulative result size', () async {
    late FakeAiAssistantRepository repository;
    repository = FakeAiAssistantRepository(
      responseStreamBuilder:
          (_) => Stream.fromIterable([
            for (var index = 0; index < 4; index++)
              AiToolCallRequested(
                id: 'call-$index',
                name: AiReadToolNames.listTasks,
                arguments: const {'limit': 50},
              ),
            const AiResponseCompleted(finishReason: 'tool_calls'),
          ]),
    );
    final readService = FakeAiApplicationContextReadService();
    readService.tasksContext = AiApplicationContextEnvelope(
      generatedAt: DateTime.utc(2026, 8, 30),
      attachments: [
        AiActiveTasksContextAttachment(
          tasks: [
            for (var index = 0; index < 50; index++)
              AiTaskContextItem(
                title: '${List.filled(195, 'x').join()}$index',
                isCompleted: false,
              ),
          ],
          omittedCount: 0,
        ),
      ],
    );
    final authorization = AiReadToolAuthorization(allowActiveTasks: true);
    final coordinator = AiReadToolCoordinator(
      assistantRepository: repository,
      readService: readService,
    );
    final handle = await coordinator.startResponse(
      _request(profile, authorization),
      scope: AiReadToolExecutionScope(authorization: authorization),
    );

    final events = await handle.events.toList();

    expect((events.single as AiResponseFailed).code, 'tool_result_limit');
    expect(repository.startedRequests, hasLength(1));
  });

  test('times out reads and cancellation prevents continuation', () async {
    late FakeAiAssistantRepository timeoutRepository;
    timeoutRepository = FakeAiAssistantRepository(
      responseStreamBuilder: (_) {
        if (timeoutRepository.startedRequests.length == 1) {
          return Stream.fromIterable([
            AiToolCallRequested(
              id: 'call-timeout',
              name: AiReadToolNames.listTasks,
              arguments: const {'limit': 1},
            ),
            const AiResponseCompleted(finishReason: 'tool_calls'),
          ]);
        }
        return Stream.fromIterable(const [
          AiTextDelta('Timed out safely.'),
          AiResponseCompleted(),
        ]);
      },
    );
    final timeoutReads = _BlockingReadService();
    final authorization = AiReadToolAuthorization(allowActiveTasks: true);
    final timeoutCoordinator = AiReadToolCoordinator(
      assistantRepository: timeoutRepository,
      readService: timeoutReads,
      executionTimeout: const Duration(milliseconds: 5),
    );
    final timeoutHandle = await timeoutCoordinator.startResponse(
      _request(profile, authorization),
      scope: AiReadToolExecutionScope(authorization: authorization),
    );

    final timeoutEvents = await timeoutHandle.events.toList();

    expect(timeoutEvents.last, isA<AiResponseCompleted>());
    final timeoutResult =
        timeoutRepository.startedRequests.last.continuationMessages
            .whereType<AiToolResultMessage>()
            .single;
    expect(timeoutResult.result['code'], 'timeout');

    late FakeAiAssistantRepository cancelRepository;
    cancelRepository = FakeAiAssistantRepository(
      responseStreamBuilder:
          (_) => Stream.fromIterable([
            AiToolCallRequested(
              id: 'call-cancel',
              name: AiReadToolNames.listTasks,
              arguments: const {'limit': 1},
            ),
            const AiResponseCompleted(finishReason: 'tool_calls'),
          ]),
    );
    final cancelReads = _BlockingReadService();
    final cancelCoordinator = AiReadToolCoordinator(
      assistantRepository: cancelRepository,
      readService: cancelReads,
      executionTimeout: const Duration(minutes: 1),
    );
    final cancelHandle = await cancelCoordinator.startResponse(
      _request(profile, authorization),
      scope: AiReadToolExecutionScope(authorization: authorization),
    );
    final cancelEvents = cancelHandle.events.toList();
    await cancelReads.started.future;

    await cancelHandle.cancel();
    cancelReads.complete(_taskContext('Cancelled'));

    expect(await cancelEvents, isEmpty);
    expect(cancelRepository.startedRequests, hasLength(1));
  });
}

AiChatRequest _request(
  AiConnectionProfile profile,
  AiReadToolAuthorization authorization,
) => AiChatRequest(
  connectionProfile: profile,
  conversationId: 'conversation-1',
  messages: [
    AiChatMessage(
      id: 'message-1',
      role: AiMessageRole.user,
      content: 'Help me plan.',
      createdAt: DateTime.utc(2026, 8, 30),
    ),
  ],
  readToolAuthorization: authorization,
);

AiApplicationContextEnvelope _taskContext(String title) =>
    AiApplicationContextEnvelope(
      generatedAt: DateTime.utc(2026, 8, 30),
      attachments: [
        AiActiveTasksContextAttachment(
          tasks: [AiTaskContextItem(title: title, isCompleted: false)],
          omittedCount: 0,
        ),
      ],
    );

AiApplicationContextEnvelope _noteContext(String title, String content) =>
    AiApplicationContextEnvelope(
      generatedAt: DateTime.utc(2026, 8, 30),
      attachments: [
        AiSelectedNotesContextAttachment(
          notes: [
            AiNoteContextItem(
              title: title,
              contentType: AiContextNoteContentType.text,
              content: content,
              checklistItems: const [],
              omittedChecklistItemCount: 0,
            ),
          ],
          omittedCount: 0,
        ),
      ],
    );

class _BlockingReadService extends FakeAiApplicationContextReadService {
  final started = Completer<void>();
  final _result = Completer<AiApplicationContextEnvelope>();

  @override
  Future<AiApplicationContextEnvelope> listTasks({
    required AiApplicationReadScope scope,
    int limit = AiApplicationContextLimits.maxActiveTasks,
  }) {
    if (!started.isCompleted) started.complete();
    return _result.future;
  }

  void complete(AiApplicationContextEnvelope value) {
    if (!_result.isCompleted) _result.complete(value);
  }
}
