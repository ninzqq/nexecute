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
    expect(conversationStore.watchConversationsCallCount, 1);

    await conversationStore.deleteConversation(latest.id);
    await _flushEvents();

    expect(controller.conversation, isNull);
    expect(controller.messages, isEmpty);
  });

  test('sends, streams, and persists a completed conversation', () async {
    var nextId = 0;
    var nextMicros = 0;
    final repository = FakeAiAssistantRepository(
      responseEvents: const [
        AiReasoningDelta('First'),
        AiReasoningDelta(' thought'),
        AiTextDelta('Hello'),
        AiResponseCompleted(),
      ],
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
      saved.messages.any(
        (message) => message.content.contains(aiDefaultSystemPrompt),
      ),
      isFalse,
    );
    expect(
      controller.reasoningForMessage(saved.messages.last.id),
      'First thought',
    );
    expect(saved.messages.last.content, isNot(contains('First thought')));
    expect(
      repository.startedRequests.single.messages.single.content,
      'Plan tomorrow',
    );
    expect(
      repository.startedRequests.single.systemInstruction,
      startsWith('[IMMUTABLE NEXECUTE POLICY]'),
    );
    expect(
      repository.startedRequests.single.systemInstruction,
      contains(aiDefaultSystemPrompt.split('\n').first),
    );
    expect(controller.isGenerating, isFalse);
  });

  test(
    'starts a local response while Firestore acknowledgement is pending',
    () async {
      final pendingStore = _PendingPersistenceConversationStore();
      addTearDown(pendingStore.dispose);
      final repository = FakeAiAssistantRepository(
        responseEvents: const [
          AiTextDelta('Offline answer'),
          AiResponseCompleted(),
        ],
      );
      var nextId = 0;
      final controller = AiChatController(
        assistantRepository: repository,
        connectionProfileStore: profileStore,
        conversationStore: pendingStore,
        idFactory: () => 'offline-${nextId++}',
        clock: () => DateTime.utc(2026, 8, 30, 12),
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      final started = await controller
          .send('Work without Firestore connectivity')
          .timeout(const Duration(seconds: 1));
      await _flushEvents();

      expect(started, isTrue);
      expect(repository.startedRequests, hasLength(1));
      expect(
        controller.messages.first.content,
        'Work without Firestore connectivity',
      );
    },
  );

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
    final diagnostic = AiDiagnostic(
      kind: AiDiagnosticKind.localNetwork,
      title: 'Local endpoint unreachable',
      summary: 'This device could not reach the private endpoint.',
      suggestions: const ['Check that both devices use the same network.'],
    );
    final repository = FakeAiAssistantRepository(
      responseEvents: [
        const AiTextDelta('The beginning'),
        AiResponseFailed(
          error: StateError('offline'),
          message: 'Connection lost',
          retryable: true,
          diagnostic: diagnostic,
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
    expect(saved.messages.last.diagnostic, same(diagnostic));
    expect(repository.startedRequests, hasLength(1));
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
      expect(repository.startedRequests, hasLength(1));
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

  test('executes scoped reads without persisting tool transcripts', () async {
    profile = profile.copyWith(
      capabilityOverrides: const {AiCapability.tools: true},
    );
    await profileStore.saveProfile(profile);
    late FakeAiAssistantRepository repository;
    repository = FakeAiAssistantRepository(
      responseStreamBuilder: (_) {
        if (repository.startedRequests.length == 1) {
          return Stream.fromIterable([
            AiToolCallRequested(
              id: 'call-1',
              name: AiReadToolNames.listTasks,
              arguments: const {'limit': 5},
            ),
            const AiResponseCompleted(finishReason: 'tool_calls'),
          ]);
        }
        return Stream.fromIterable(const [
          AiTextDelta('Finish the bounded coordinator.'),
          AiResponseCompleted(),
        ]);
      },
    );
    final readService = FakeAiApplicationContextReadService();
    readService.tasksContext = AiApplicationContextEnvelope(
      generatedAt: DateTime.utc(2026, 8, 30),
      attachments: [
        AiActiveTasksContextAttachment(
          tasks: const [
            AiTaskContextItem(
              title: 'Private task context',
              isCompleted: false,
            ),
          ],
          omittedCount: 0,
        ),
      ],
    );
    final authorization = AiReadToolAuthorization(allowActiveTasks: true);
    var nextId = 0;
    final controller = AiChatController(
      assistantRepository: repository,
      connectionProfileStore: profileStore,
      conversationStore: conversationStore,
      readToolCoordinator: AiReadToolCoordinator(
        assistantRepository: repository,
        readService: readService,
      ),
      idFactory: () => 'id-${nextId++}',
      clock: () => DateTime.utc(2026, 8, 30, 12),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.send(
      'Plan my work',
      readToolExecutionScope: AiReadToolExecutionScope(
        authorization: authorization,
      ),
    );
    await _flushEvents();
    await _flushEvents();

    final saved = (await conversationStore.getConversations()).single;
    expect(saved.messages, hasLength(2));
    expect(saved.messages.first.content, 'Plan my work');
    expect(saved.messages.last.content, 'Finish the bounded coordinator.');
    expect(
      saved.messages.any(
        (message) =>
            message.role == AiMessageRole.tool ||
            message.content.contains('Private task context') ||
            message.content.contains('call-1'),
      ),
      isFalse,
    );
    expect(repository.startedRequests, hasLength(2));
    expect(repository.startedRequests.last.continuationMessages, hasLength(2));
  });

  test('persists conversation skills and sends resolved snapshots', () async {
    final skill = _skill('suomen-kieli', 'Kirjoita aina hyvää suomea.');
    final skillStore = InMemoryAiSkillStore(skills: [skill]);
    final repository = FakeAiAssistantRepository();
    var nextId = 0;
    final controller = AiChatController(
      assistantRepository: repository,
      connectionProfileStore: profileStore,
      conversationStore: conversationStore,
      skillStore: skillStore,
      idFactory: () => 'skill-${nextId++}',
      clock: () => DateTime.utc(2026, 9, 5, 12),
    );
    addTearDown(controller.dispose);
    addTearDown(skillStore.dispose);
    await controller.initialize();
    await controller.setActiveSkills([AiSkillReference.fromSkill(skill)]);

    expect(await controller.send('Hei'), isTrue);
    await _flushEvents();

    final request = repository.startedRequests.single;
    expect(request.resolvedSkills.single.id, skill.id);
    expect(request.resolvedSkills.single.contentHash, skill.contentHash);
    expect(
      request.systemInstruction,
      startsWith('[IMMUTABLE NEXECUTE POLICY]'),
    );
    expect(request.systemInstruction, contains(r'Kirjoita aina hyvää suomea.'));
    final saved = (await conversationStore.getConversations()).single;
    expect(saved.activeSkills, [AiSkillReference.fromSkill(skill)]);
    expect(
      saved.messages.any(
        (message) => message.content.contains(skill.instructions),
      ),
      isFalse,
    );
  });

  test('applies a next-request skill override exactly once', () async {
    final persistent = _skill('persistent', 'Persistent instructions');
    final once = _skill('once', 'One request only');
    final skillStore = InMemoryAiSkillStore(skills: [persistent, once]);
    final repository = FakeAiAssistantRepository();
    var nextId = 0;
    final controller = AiChatController(
      assistantRepository: repository,
      connectionProfileStore: profileStore,
      conversationStore: conversationStore,
      skillStore: skillStore,
      idFactory: () => 'override-${nextId++}',
      clock: () => DateTime.utc(2026, 9, 5, 13, 0, nextId),
    );
    addTearDown(controller.dispose);
    addTearDown(skillStore.dispose);
    await controller.initialize();
    await controller.setActiveSkills([AiSkillReference.fromSkill(persistent)]);
    await controller.setActiveSkills([
      AiSkillReference.fromSkill(once),
    ], scope: AiSkillActivationScope.nextRequest);

    await controller.send('First');
    await _flushEvents();
    await controller.send('Second');
    await _flushEvents();

    expect(repository.startedRequests, hasLength(2));
    expect(repository.startedRequests.first.resolvedSkills.single.id, 'once');
    expect(
      repository.startedRequests.last.resolvedSkills.single.id,
      'persistent',
    );
    expect(controller.nextRequestSkills, isNull);
    expect(controller.conversationSkills.single.id, 'persistent');
  });

  test(
    'blocks changed skills until explicitly continuing without them',
    () async {
      final previous = _skill('review', 'Previous instructions');
      final current = _skill('review', 'Changed instructions');
      final skillStore = InMemoryAiSkillStore(skills: [current]);
      final repository = FakeAiAssistantRepository();
      var nextId = 0;
      final controller = AiChatController(
        assistantRepository: repository,
        connectionProfileStore: profileStore,
        conversationStore: conversationStore,
        skillStore: skillStore,
        idFactory: () => 'mismatch-${nextId++}',
        clock: () => DateTime.utc(2026, 9, 5, 14),
      );
      addTearDown(controller.dispose);
      addTearDown(skillStore.dispose);
      await controller.initialize();
      await controller.setActiveSkills([AiSkillReference.fromSkill(previous)]);

      expect(await controller.send('Review this'), isFalse);
      expect(repository.startedRequests, isEmpty);
      expect(controller.messages, isEmpty);
      expect(
        controller.skillResolutionError?.issues.single.kind,
        AiSkillResolutionIssueKind.changed,
      );

      expect(
        await controller.send(
          'Review this',
          skillMismatchAction: AiSkillMismatchAction.continueWithoutSkills,
        ),
        isTrue,
      );
      await _flushEvents();

      expect(repository.startedRequests.single.resolvedSkills, isEmpty);
      expect(
        controller.conversationSkills.single.contentHash,
        previous.contentHash,
      );
    },
  );

  test(
    'budget failure saves nothing and preserves the one-request skill selection',
    () async {
      final skill = _skill('large', 'ä' * 11000);
      final skills = InMemoryAiSkillStore(skills: [skill]);
      final repository = FakeAiAssistantRepository();
      final controller = AiChatController(
        assistantRepository: repository,
        connectionProfileStore: profileStore,
        conversationStore: conversationStore,
        skillStore: skills,
      );
      addTearDown(controller.dispose);
      addTearDown(skills.dispose);
      await controller.initialize();
      await controller.setActiveSkills([
        AiSkillReference.fromSkill(skill),
      ], scope: AiSkillActivationScope.nextRequest);
      expect(await controller.send('Hello'), isFalse);
      expect(controller.errorMessage, contains('Nothing was truncated'));
      expect(repository.startedRequests, isEmpty);
      expect(await conversationStore.getConversations(), isEmpty);
      expect(controller.nextRequestSkills, [AiSkillReference.fromSkill(skill)]);
    },
  );

  test('loads local default skills only for a new conversation', () async {
    final skill = _skill('default-skill', 'Default instructions');
    final skillStore = InMemoryAiSkillStore(skills: [skill]);
    final preferences = InMemoryAiSkillPreferencesStore(
      defaultSkills: [AiSkillReference.fromSkill(skill)],
    );
    final repository = FakeAiAssistantRepository();
    var nextId = 0;
    final controller = AiChatController(
      assistantRepository: repository,
      connectionProfileStore: profileStore,
      conversationStore: conversationStore,
      skillStore: skillStore,
      skillPreferencesStore: preferences,
      idFactory: () => 'default-${nextId++}',
      clock: () => DateTime.utc(2026, 9, 6),
    );
    addTearDown(controller.dispose);
    addTearDown(skillStore.dispose);
    addTearDown(preferences.dispose);

    await controller.initialize();
    expect(controller.conversationSkills, [AiSkillReference.fromSkill(skill)]);
    await controller.send('Use the default');
    await _flushEvents();

    expect(
      repository.startedRequests.single.resolvedSkills.single.id,
      skill.id,
    );
    expect((await conversationStore.getConversations()).single.activeSkills, [
      AiSkillReference.fromSkill(skill),
    ]);
  });
}

Future<void> _flushEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

AiSkill _skill(String id, String instructions) => AiSkill(
  id: id,
  name: id,
  description: 'Controller test skill',
  instructions: instructions,
  createdAt: DateTime.utc(2026, 9, 5),
  updatedAt: DateTime.utc(2026, 9, 5),
);

class _PendingPersistenceConversationStore extends InMemoryAiConversationStore {
  final _acknowledgement = Completer<void>();

  @override
  Future<void> saveConversation(AiConversation conversation) async {
    await super.saveConversation(conversation);
    await _acknowledgement.future;
  }

  @override
  Future<void> saveMessage(String conversationId, AiChatMessage message) async {
    await super.saveMessage(conversationId, message);
    await _acknowledgement.future;
  }
}
