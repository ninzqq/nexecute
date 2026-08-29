import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  late AiConnectionProfile profile;
  late FakeAiConnectionProfileStore profileStore;
  late FakeAiConversationStore conversationStore;

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
    conversationStore = FakeAiConversationStore();
  });

  tearDown(() {
    profileStore.dispose();
    conversationStore.dispose();
  });

  test('opens the most recently updated conversation on initialize', () async {
    final older = AiConversation(
      id: 'older',
      title: 'Older conversation',
      connectionProfileId: profile.id,
      modelId: profile.modelId,
      createdAt: DateTime.utc(2026, 8, 27),
      updatedAt: DateTime.utc(2026, 8, 28),
    );
    final latest = AiConversation(
      id: 'latest',
      title: 'Latest conversation',
      connectionProfileId: profile.id,
      modelId: profile.modelId,
      createdAt: DateTime.utc(2026, 8, 28),
      updatedAt: DateTime.utc(2026, 8, 29),
      messages: [
        AiChatMessage(
          id: 'latest-message',
          role: AiMessageRole.assistant,
          content: 'Most recent answer',
          createdAt: DateTime.utc(2026, 8, 29),
        ),
      ],
    );
    await conversationStore.saveConversation(older);
    await conversationStore.saveConversation(latest);
    final controller = AiChatController(
      assistantRepository: FakeAiAssistantRepository(),
      connectionProfileStore: profileStore,
      conversationStore: conversationStore,
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.conversation?.id, latest.id);
    expect(controller.messages.single.content, 'Most recent answer');
  });

  test('sends, streams, and persists a completed conversation', () async {
    var nextId = 0;
    var nextMicros = 0;
    final repository = FakeAiAssistantRepository(
      responseEvents: const [AiTextDelta('Hello'), AiResponseCompleted()],
    );
    final controller = AiChatController(
      assistantRepository: repository,
      connectionProfileStore: profileStore,
      conversationStore: conversationStore,
      idFactory: () => 'id-${nextId++}',
      clock:
          () => DateTime.utc(
            2026,
            8,
            29,
          ).add(Duration(microseconds: nextMicros++)),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.send('Plan tomorrow');
    await _flushEvents();

    final saved = (await conversationStore.getConversations()).single;
    expect(saved.title, 'Plan tomorrow');
    expect(saved.messages, hasLength(2));
    expect(saved.messages.first.role, AiMessageRole.user);
    expect(saved.messages.last.content, 'Hello');
    expect(saved.messages.last.status, AiMessageStatus.complete);
    expect(
      repository.startedRequests.single.messages.single.content,
      'Plan tomorrow',
    );
    expect(controller.isGenerating, isFalse);
  });

  test('stop aborts generation and preserves the partial response', () async {
    final stream = StreamController<AiStreamEvent>();
    final repository = FakeAiAssistantRepository(
      responseStreamBuilder: (_) => stream.stream,
    );
    var nextId = 0;
    final controller = AiChatController(
      assistantRepository: repository,
      connectionProfileStore: profileStore,
      conversationStore: conversationStore,
      idFactory: () => 'id-${nextId++}',
      clock: () => DateTime.utc(2026, 8, 29, 12, 0, nextId),
    );
    addTearDown(controller.dispose);
    addTearDown(stream.close);
    await controller.initialize();
    await controller.send('Write something');
    stream.add(const AiTextDelta('A partial answer'));
    await _flushEvents();

    await controller.stopResponse();
    await _flushEvents();

    final saved = (await conversationStore.getConversations()).single;
    expect(repository.cancellationCount, 1);
    expect(saved.messages.last.content, 'A partial answer');
    expect(saved.messages.last.status, AiMessageStatus.cancelled);
    expect(controller.canRetry, isTrue);
  });

  test('stream failure preserves partial text as a failed message', () async {
    final repository = FakeAiAssistantRepository(
      responseEvents: [
        const AiTextDelta('The beginning'),
        AiResponseFailed(
          error: StateError('offline'),
          message: 'Connection lost',
          retryable: true,
        ),
      ],
    );
    var nextId = 0;
    final controller = AiChatController(
      assistantRepository: repository,
      connectionProfileStore: profileStore,
      conversationStore: conversationStore,
      idFactory: () => 'id-${nextId++}',
      clock: () => DateTime.utc(2026, 8, 29, 12, 0, nextId),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.send('Keep partial output');
    await _flushEvents();

    final saved = (await conversationStore.getConversations()).single;
    expect(saved.messages.last.content, 'The beginning');
    expect(saved.messages.last.status, AiMessageStatus.failed);
    expect(saved.messages.last.errorMessage, 'Connection lost');
  });

  test(
    'retry replaces a failed assistant response without duplicating user text',
    () async {
      final repository = FakeAiAssistantRepository(
        responseEvents: [
          AiResponseFailed(
            error: StateError('offline'),
            message: 'Offline',
            retryable: true,
          ),
        ],
      );
      var nextId = 0;
      final controller = AiChatController(
        assistantRepository: repository,
        connectionProfileStore: profileStore,
        conversationStore: conversationStore,
        idFactory: () => 'id-${nextId++}',
        clock: () => DateTime.utc(2026, 8, 29, 12, 0, nextId),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.send('Try this');
      await _flushEvents();
      repository.responseEvents = const [
        AiTextDelta('Recovered'),
        AiResponseCompleted(),
      ];

      await controller.retryLastResponse();
      await _flushEvents();

      final saved = (await conversationStore.getConversations()).single;
      expect(
        saved.messages.where((m) => m.role == AiMessageRole.user),
        hasLength(1),
      );
      expect(saved.messages.last.content, 'Recovered');
      expect(saved.messages.last.status, AiMessageStatus.complete);
      expect(repository.startedRequests, hasLength(2));
    },
  );
}

Future<void> _flushEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
