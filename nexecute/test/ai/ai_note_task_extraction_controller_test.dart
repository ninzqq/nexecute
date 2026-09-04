import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  late AiConnectionProfile profile;
  late FakeAiConnectionProfileStore profileStore;

  setUp(() {
    profile = AiConnectionProfile(
      id: 'home',
      name: 'Home AI',
      protocol: AiProtocol.openAiCompatibleChat,
      baseUrl: Uri.parse('https://ai.example.test/v1'),
      modelId: 'local-model',
    );
    profileStore = FakeAiConnectionProfileStore(
      profiles: [profile],
      activeProfileId: profile.id,
    );
  });

  tearDown(() => profileStore.dispose());

  test('requests and parses task proposals without creating a chat', () async {
    final repository = FakeAiAssistantRepository(
      responseEvents: const [
        AiReasoningDelta('The note contains one concrete action.'),
        AiTextDelta('{"schemaVersion":1,"tasks":[{"title":"Buy coffee"}]}'),
        AiResponseCompleted(),
      ],
    );
    final controller = AiNoteTaskExtractionController(
      assistantRepository: repository,
      connectionProfileStore: profileStore,
      idFactory: () => 'request-message',
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.start(
      noteId: 'note-1',
      noteTitle: 'Shopping',
      noteContent: 'Remember to buy coffee.',
    );
    await _flushEvents();

    expect(controller.status, AiNoteTaskExtractionStatus.completed);
    expect(controller.reasoning, 'The note contains one concrete action.');
    expect(controller.proposal?.tasks.single.title, 'Buy coffee');
    final request = repository.startedRequests.single;
    expect(request.conversationId, 'note-task-extraction:note-1');
    expect(
      request.systemInstruction,
      AiNoteTaskPromptBuilder.systemInstruction,
    );
    expect(request.resolvedSkills, isEmpty);
    expect(
      request.messages.single.content,
      contains('Remember to buy coffee.'),
    );
  });

  test('cancels an in-progress extraction request', () async {
    final stream = StreamController<AiStreamEvent>();
    addTearDown(stream.close);
    final repository = FakeAiAssistantRepository(
      responseStreamBuilder: (_) => stream.stream,
    );
    final controller = AiNoteTaskExtractionController(
      assistantRepository: repository,
      connectionProfileStore: profileStore,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.start(
      noteId: 'note-1',
      noteTitle: 'Plan',
      noteContent: 'Call Sam.',
    );
    expect(controller.status, AiNoteTaskExtractionStatus.generating);

    await controller.cancel();

    expect(repository.cancellationCount, 1);
    expect(controller.status, AiNoteTaskExtractionStatus.cancelled);
    expect(controller.proposal, isNull);
  });

  test('retains structured guidance from a response failure', () async {
    final diagnostic = AiDiagnostic(
      kind: AiDiagnosticKind.timeout,
      title: 'Endpoint timed out',
      summary: 'The endpoint did not respond before the configured timeout.',
      suggestions: const ['Check whether the model is still starting.'],
    );
    final repository = FakeAiAssistantRepository(
      responseEvents: [
        AiResponseFailed(
          error: TimeoutException('private detail'),
          message: diagnostic.summary,
          retryable: true,
          diagnostic: diagnostic,
        ),
      ],
    );
    final controller = AiNoteTaskExtractionController(
      assistantRepository: repository,
      connectionProfileStore: profileStore,
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.start(
      noteId: 'note-1',
      noteTitle: 'Plan',
      noteContent: 'Call Sam.',
    );
    await _flushEvents();

    expect(controller.status, AiNoteTaskExtractionStatus.failed);
    expect(controller.diagnostic, same(diagnostic));
    expect(controller.errorMessage, diagnostic.summary);
    expect(repository.startedRequests, hasLength(1));
  });

  test('supports editing and selecting parsed task proposals locally', () async {
    final repository = FakeAiAssistantRepository(
      responseEvents: const [
        AiTextDelta(
          '{"schemaVersion":1,"tasks":[{"title":"Buy coffee"},{"title":"Call Sam"}]}',
        ),
        AiResponseCompleted(),
      ],
    );
    final controller = AiNoteTaskExtractionController(
      assistantRepository: repository,
      connectionProfileStore: profileStore,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.start(
      noteId: 'note-1',
      noteTitle: 'Plan',
      noteContent: 'Buy coffee and call Sam.',
    );
    await _flushEvents();

    expect(controller.reviewItems, hasLength(2));
    expect(controller.selectedTaskCount, 2);
    controller.setTaskSelected(0, false);
    expect(controller.selectedTaskCount, 1);
    expect(controller.updateTaskTitle(1, '  Call Alex  '), isTrue);
    expect(controller.reviewItems[1].title, 'Call Alex');
    expect(controller.selectedTasks.single.title, 'Call Alex');
    expect(controller.updateTaskTitle(1, 'Buy coffee'), isFalse);
    expect(
      controller.validateTaskTitle('Buy coffee', editingIndex: 1),
      'This task is already in the proposal.',
    );
    controller.setAllTasksSelected(false);
    expect(controller.selectedTaskCount, 0);
  });
}

Future<void> _flushEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
