import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  final now = DateTime.utc(2026, 9, 13, 10);

  AiConnectionProfile profile({int contextWindowTokens = 8192}) =>
      AiConnectionProfile(
        id: 'home',
        name: 'Home AI',
        protocol: AiProtocol.openAiCompatibleChat,
        baseUrl: Uri.parse('https://ai.example.test/v1'),
        modelId: 'local-model',
        contextWindowTokens: contextWindowTokens,
      );

  AiConversationNoteSource source({String userText = 'Plan the launch.'}) =>
      AiConversationNoteSource.fromConversation(
        AiConversation(
          id: 'conversation',
          title: 'Planning',
          connectionProfileId: 'home',
          modelId: 'local-model',
          createdAt: now,
          updatedAt: now,
          messages: [
            AiChatMessage(
              id: 'u1',
              role: AiMessageRole.user,
              content: userText,
              createdAt: now,
            ),
            AiChatMessage(
              id: 'a1',
              role: AiMessageRole.assistant,
              content: 'Decide a date and budget.',
              createdAt: now.add(const Duration(minutes: 1)),
            ),
          ],
        ),
      )!;

  test('sends the frozen source with no tools or chat persistence', () async {
    final active = profile();
    final profiles = FakeAiConnectionProfileStore(
      profiles: [active],
      activeProfileId: active.id,
    );
    addTearDown(profiles.dispose);
    final repository = FakeAiAssistantRepository(
      responseEvents: const [
        AiReasoningDelta('Summarizing decisions.'),
        AiTextDelta(
          '{"schemaVersion":1,"note":{"title":"Launch plan","body":"Decide a date and budget."}}',
        ),
        AiResponseCompleted(),
      ],
    );
    final controller = AiConversationNoteGenerationController(
      assistantRepository: repository,
      connectionProfileStore: profiles,
      previewedProfile: active,
      idFactory: () => 'request-message',
      clock: () => now,
    );
    addTearDown(controller.dispose);
    final snapshot = source();

    await controller.start(snapshot);
    await _flushEvents();

    expect(controller.status, AiConversationNoteGenerationStatus.completed);
    expect(controller.proposal?.note?.title, 'Launch plan');
    expect(controller.reasoning, 'Summarizing decisions.');
    final request = repository.startedRequests.single;
    expect(request.conversationId, 'conversation-note-proposal:conversation');
    expect(
      request.systemInstruction,
      AiConversationNotePromptBuilder.systemInstruction,
    );
    expect(
      request.messages.single.content,
      AiConversationNotePromptBuilder.build(snapshot).userMessage,
    );
    expect(request.toolDefinitions, isEmpty);
    expect(request.applicationContext, isNull);
    expect(request.resolvedSkills, isEmpty);
  });

  test('rejects a changed destination and an oversized model budget', () async {
    final active = profile();
    final profiles = FakeAiConnectionProfileStore(
      profiles: [active],
      activeProfileId: active.id,
    );
    addTearDown(profiles.dispose);
    final repository = FakeAiAssistantRepository();
    final controller = AiConversationNoteGenerationController(
      assistantRepository: repository,
      connectionProfileStore: profiles,
      previewedProfile: active,
    );
    addTearDown(controller.dispose);
    await profiles.saveProfile(active.copyWith(modelId: 'different-model'));

    await controller.start(source());
    expect(controller.status, AiConversationNoteGenerationStatus.failed);
    expect(controller.errorMessage, contains('changed'));
    expect(repository.startedRequests, isEmpty);

    await profiles.saveProfile(active);
    await controller.start(source(userText: 'x' * 7000));
    expect(controller.status, AiConversationNoteGenerationStatus.failed);
    expect(controller.errorMessage, contains('Nothing was truncated'));
    expect(repository.startedRequests, isEmpty);
  });

  test(
    'blocks duplicate starts and cancellation during connection check',
    () async {
      final active = profile();
      final profiles = _DelayedProfileStore(active);
      addTearDown(profiles.dispose);
      final repository = FakeAiAssistantRepository();
      final controller = AiConversationNoteGenerationController(
        assistantRepository: repository,
        connectionProfileStore: profiles,
        previewedProfile: active,
      );
      addTearDown(controller.dispose);

      final first = controller.start(source());
      final second = controller.start(source());
      expect(controller.status, AiConversationNoteGenerationStatus.generating);
      await controller.cancel();
      profiles.release();
      await Future.wait([first, second]);

      expect(controller.status, AiConversationNoteGenerationStatus.cancelled);
      expect(repository.startedRequests, isEmpty);
    },
  );

  test('cancels an in-progress response and discards late output', () async {
    final active = profile();
    final profiles = FakeAiConnectionProfileStore(
      profiles: [active],
      activeProfileId: active.id,
    );
    final events = StreamController<AiStreamEvent>();
    addTearDown(profiles.dispose);
    addTearDown(events.close);
    final repository = FakeAiAssistantRepository(
      responseStreamBuilder: (_) => events.stream,
    );
    final controller = AiConversationNoteGenerationController(
      assistantRepository: repository,
      connectionProfileStore: profiles,
      previewedProfile: active,
    );
    addTearDown(controller.dispose);

    await controller.start(source());
    expect(controller.status, AiConversationNoteGenerationStatus.generating);
    events.add(const AiTextDelta('{"schemaVersion":1,'));
    await _flushEvents();
    await controller.cancel();
    events.add(const AiTextDelta('"note":null}'));
    events.add(const AiResponseCompleted());
    await _flushEvents();

    expect(repository.cancellationCount, 1);
    expect(controller.status, AiConversationNoteGenerationStatus.cancelled);
    expect(controller.proposal, isNull);
  });

  test('accepts an explicit no-proposal response', () async {
    final active = profile();
    final profiles = FakeAiConnectionProfileStore(
      profiles: [active],
      activeProfileId: active.id,
    );
    addTearDown(profiles.dispose);
    final repository = FakeAiAssistantRepository(
      responseEvents: const [
        AiTextDelta('{"schemaVersion":1,"note":null}'),
        AiResponseCompleted(),
      ],
    );
    final controller = AiConversationNoteGenerationController(
      assistantRepository: repository,
      connectionProfileStore: profiles,
      previewedProfile: active,
    );
    addTearDown(controller.dispose);
    await controller.start(source());
    await _flushEvents();

    expect(controller.status, AiConversationNoteGenerationStatus.completed);
    expect(controller.proposal?.note, isNull);
    expect(controller.errorMessage, isNull);
  });

  test('shows a provider failure without accepting partial output', () async {
    final active = profile();
    final profiles = FakeAiConnectionProfileStore(
      profiles: [active],
      activeProfileId: active.id,
    );
    addTearDown(profiles.dispose);
    final repository = FakeAiAssistantRepository(
      responseEvents: const [
        AiTextDelta('{"schemaVersion":1,'),
        AiResponseFailed(
          error: 'endpoint-unavailable',
          message: 'The model endpoint is unavailable.',
          code: 'unreachable',
          retryable: true,
        ),
      ],
    );
    final controller = AiConversationNoteGenerationController(
      assistantRepository: repository,
      connectionProfileStore: profiles,
      previewedProfile: active,
    );
    addTearDown(controller.dispose);

    await controller.start(source());
    await _flushEvents();
    expect(controller.status, AiConversationNoteGenerationStatus.failed);
    expect(controller.proposal, isNull);
    expect(controller.errorMessage, 'The model endpoint is unavailable.');
  });

  test('fails safely on malformed and excessive output', () async {
    final active = profile();
    final profiles = FakeAiConnectionProfileStore(
      profiles: [active],
      activeProfileId: active.id,
    );
    addTearDown(profiles.dispose);
    final repository = FakeAiAssistantRepository(
      responseEvents: const [
        AiTextDelta('{"schemaVersion":1,"note":{"title":"Bad"}}'),
        AiResponseCompleted(),
      ],
    );
    final controller = AiConversationNoteGenerationController(
      assistantRepository: repository,
      connectionProfileStore: profiles,
      previewedProfile: active,
    );
    addTearDown(controller.dispose);

    await controller.start(source());
    await _flushEvents();
    expect(controller.status, AiConversationNoteGenerationStatus.failed);
    expect(controller.proposal, isNull);

    repository.responseEvents = [
      AiTextDelta('x' * (aiMaxNoteProposalResponseCharacters + 1)),
      const AiResponseCompleted(),
    ];
    await controller.start(source());
    await _flushEvents();
    expect(controller.status, AiConversationNoteGenerationStatus.failed);
    expect(controller.errorMessage, contains('too large'));
    expect(repository.cancellationCount, 1);
  });
}

final class _DelayedProfileStore extends FakeAiConnectionProfileStore {
  _DelayedProfileStore(AiConnectionProfile profile)
    : super(profiles: [profile], activeProfileId: profile.id);

  final Completer<void> _gate = Completer<void>();

  @override
  Future<AiConnectionProfile?> getActiveProfile() async {
    await _gate.future;
    return super.getActiveProfile();
  }

  void release() => _gate.complete();
}

Future<void> _flushEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
