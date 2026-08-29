import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:provider/provider.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  testWidgets('previews exact note data before sending it to the active AI', (
    tester,
  ) async {
    final profile = AiConnectionProfile(
      id: 'home',
      name: 'Home AI',
      protocol: AiProtocol.openAiCompatibleChat,
      baseUrl: Uri.parse('https://ai.example.test/v1'),
      modelId: 'local-model',
    );
    final profileStore = FakeAiConnectionProfileStore(
      profiles: [profile],
      activeProfileId: profile.id,
    );
    final repository = FakeAiAssistantRepository(
      responseEvents: const [
        AiTextDelta('{"schemaVersion":1,"tasks":[]}'),
        AiResponseCompleted(),
      ],
    );
    final note = Quicxec(
      id: 'note-1',
      title: 'Weekend plan',
      text: 'Buy coffee and call Sam.',
      created: DateTime.utc(2026, 8, 29),
    );
    addTearDown(profileStore.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AiAssistantRepository>.value(value: repository),
          Provider<AiConnectionProfileStore>.value(value: profileStore),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => FilledButton(
                    onPressed:
                        () => showAiNoteTaskExtractionPreview(
                          context,
                          note: note,
                        ),
                    child: const Text('Open preview'),
                  ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();

    expect(find.text('Home AI · local-model'), findsOneWidget);
    expect(find.text('Weekend plan'), findsOneWidget);
    expect(find.text('Buy coffee and call Sam.'), findsOneWidget);
    expect(repository.startedRequests, isEmpty);

    await tester.tap(find.byKey(const Key('ai-note-task-technical-preview')));
    await tester.pumpAndSettle();
    expect(
      find.text(AiNoteTaskPromptBuilder.systemInstruction),
      findsOneWidget,
    );
    expect(
      find.textContaining('"content":"Buy coffee and call Sam."'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Exact technical request'));
    await tester.tap(find.text('Exact technical request'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ai-note-task-send')));
    await tester.pumpAndSettle();

    expect(repository.startedRequests, hasLength(1));
    await tester.scrollUntilVisible(
      find.byKey(const Key('ai-note-task-completed')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byKey(const Key('ai-note-task-completed')), findsOneWidget);
    expect(find.textContaining('0 task proposals received'), findsOneWidget);
  });
}
