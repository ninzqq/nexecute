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
    expect(controller.proposal?.tasks.single.title, 'Buy coffee');
    final request = repository.startedRequests.single;
    expect(request.conversationId, 'note-task-extraction:note-1');
    expect(
      request.systemInstruction,
      AiNoteTaskPromptBuilder.systemInstruction,
    );
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
}

Future<void> _flushEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
