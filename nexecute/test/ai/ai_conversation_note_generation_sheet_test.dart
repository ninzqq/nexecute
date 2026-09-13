import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:provider/provider.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  testWidgets('requires Generate and shows an unsaved note proposal', (
    tester,
  ) async {
    final profile = AiConnectionProfile(
      id: 'home',
      name: 'Home AI',
      protocol: AiProtocol.openAiCompatibleChat,
      baseUrl: Uri.parse('https://ai.example.test/v1'),
      modelId: 'local-model',
    );
    final now = DateTime.utc(2026, 9, 13);
    final source =
        AiConversationNoteSource.fromConversation(
          AiConversation(
            id: 'conversation',
            title: 'Planning',
            connectionProfileId: profile.id,
            modelId: profile.modelId,
            createdAt: now,
            updatedAt: now,
            messages: [
              AiChatMessage(
                id: 'user',
                role: AiMessageRole.user,
                content: 'We should launch in October.',
                createdAt: now,
              ),
              AiChatMessage(
                id: 'assistant',
                role: AiMessageRole.assistant,
                content: 'The budget is still open.',
                createdAt: now,
              ),
            ],
          ),
        )!;
    final profiles = FakeAiConnectionProfileStore(
      profiles: [profile],
      activeProfileId: profile.id,
    );
    final repository = FakeAiAssistantRepository(
      responseEvents: const [
        AiTextDelta(
          '{"schemaVersion":1,"note":{"title":"Launch plan","body":"Decision: October launch.\\nOpen: budget."}}',
        ),
        AiResponseCompleted(),
      ],
    );
    addTearDown(profiles.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AiAssistantRepository>.value(value: repository),
          Provider<AiConnectionProfileStore>.value(value: profiles),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => FilledButton(
                    onPressed:
                        () => showAiConversationNoteSourcePreview(
                          context,
                          source: source,
                          profile: profile,
                        ),
                    child: const Text('Open'),
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(repository.startedRequests, isEmpty);

    await tester.scrollUntilVisible(
      find.byKey(const Key('conversation-note-generate')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.byKey(const Key('conversation-note-generate')),
    );
    await tester.tap(find.byKey(const Key('conversation-note-generate')));
    await tester.pumpAndSettle();

    expect(repository.startedRequests, hasLength(1));
    expect(
      repository.startedRequests.single.messages.single.content,
      AiConversationNotePromptBuilder.build(source).userMessage,
    );
    expect(find.text('Unsaved note proposal'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('conversation-note-proposed-body')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('conversation-note-proposed-title')),
          )
          .controller!
          .text,
      'Launch plan',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('conversation-note-proposed-body')),
          )
          .controller!
          .text,
      'Decision: October launch.\nOpen: budget.',
    );
    expect(find.byKey(const Key('conversation-note-save')), findsNothing);
  });
}
