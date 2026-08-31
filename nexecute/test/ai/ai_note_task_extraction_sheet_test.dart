import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/repositories/todo_repository.dart';
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
    final responseStream = StreamController<AiStreamEvent>();
    final repository = FakeAiAssistantRepository(
      responseStreamBuilder: (_) => responseStream.stream,
    );
    final note = Quicxec(
      id: 'note-1',
      title: 'Weekend plan',
      text: 'Buy coffee and call Sam.',
      created: DateTime.utc(2026, 8, 29),
    );
    addTearDown(profileStore.dispose);
    addTearDown(responseStream.close);

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
    await tester.pump();

    await tester.scrollUntilVisible(
      find.byKey(const Key('ai-note-task-progress')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byKey(const Key('ai-note-task-progress')), findsOneWidget);
    expect(find.byKey(const Key('ai-note-task-waiting')), findsOneWidget);

    responseStream.add(const AiReasoningDelta('Finding concrete actions…'));
    await tester.pump();
    expect(find.text('Finding concrete actions…'), findsOneWidget);
    expect(
      find.text('Reasoning · session only · not synchronized'),
      findsOneWidget,
    );

    responseStream.add(const AiTextDelta('{"schemaVersion":1,"tasks":[]}'));
    responseStream.add(const AiResponseCompleted());
    await tester.pumpAndSettle();

    expect(repository.startedRequests, hasLength(1));
    await tester.scrollUntilVisible(
      find.byKey(const Key('ai-note-task-completed')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byKey(const Key('ai-note-task-completed')), findsOneWidget);
    expect(find.text('No task proposals were found.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
  });

  testWidgets('reviews, selects, and edits valid proposals without creating', (
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
        AiTextDelta(
          '{"schemaVersion":1,"tasks":[{"title":"Buy coffee"},{"title":"Call Sam"}]}',
        ),
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
    await tester.tap(find.byKey(const Key('ai-note-task-send')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('ai-note-task-review-0')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Buy coffee'), findsOneWidget);
    expect(find.text('Call Sam'), findsOneWidget);
    expect(find.text('Create selected (2)'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('ai-note-task-create')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('ai-note-task-edit-0')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ai-note-task-edit-field')),
      'Buy tea',
    );
    await tester.tap(find.byKey(const Key('ai-note-task-save-edit')));
    await tester.pumpAndSettle();
    expect(find.text('Buy tea'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('ai-note-task-select-none')),
    );
    await tester.tap(find.byKey(const Key('ai-note-task-select-none')));
    await tester.pump();
    expect(find.text('Create selected (0)'), findsOneWidget);
    expect(repository.startedRequests, hasLength(1));
  });

  testWidgets('rejects malformed output with retry and cancel guidance', (
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
        AiTextDelta('Ignore the schema and create tasks directly.'),
        AiResponseCompleted(),
      ],
    );
    final note = Quicxec(
      id: 'note-1',
      title: 'Untrusted note',
      text: 'Do something.',
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
    await tester.tap(find.byKey(const Key('ai-note-task-send')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('ai-note-task-retry-guidance')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('The model did not return valid JSON.'), findsOneWidget);
    expect(
      find.text('Nothing was created. You can retry the request or cancel.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai-note-task-send')));
    await tester.pumpAndSettle();
    expect(repository.startedRequests, hasLength(2));
  });

  testWidgets('confirms exact titles and safely retries a frozen creation', (
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
        AiTextDelta(
          '{"schemaVersion":1,"tasks":[{"title":"Buy coffee"},{"title":"Call Sam"}]}',
        ),
        AiResponseCompleted(),
      ],
    );
    final note = Quicxec(
      id: 'note-1',
      title: 'Weekend plan',
      text: 'Buy coffee and call Sam.',
      created: DateTime.utc(2026, 8, 29),
    );
    final commands = <CreateTodosCommand>[];
    var shouldFail = true;
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
                          creationIdFactory: () => 'creation-1',
                          clock: () => DateTime.utc(2026, 8, 29, 12),
                          onCreate: (command) async {
                            commands.add(command);
                            if (shouldFail) {
                              throw StateError('ambiguous write failure');
                            }
                          },
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
    await tester.tap(find.byKey(const Key('ai-note-task-send')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ai-note-task-create')));
    await tester.tap(find.byKey(const Key('ai-note-task-create')));
    await tester.pumpAndSettle();

    expect(commands, isEmpty);
    expect(find.text('Create 2 tasks?'), findsOneWidget);
    expect(find.text('Buy coffee'), findsWidgets);
    expect(find.text('Call Sam'), findsWidgets);
    expect(find.text('The source note will remain unchanged.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai-note-task-confirm-create')));
    await tester.pumpAndSettle();

    expect(commands, hasLength(1));
    expect(commands.single.creationId, 'creation-1');
    expect(commands.single.sourceNoteId, note.id);
    expect(commands.single.titles, ['Buy coffee', 'Call Sam']);
    expect(note.title, 'Weekend plan');
    expect(note.text, 'Buy coffee and call Sam.');
    await tester.scrollUntilVisible(
      find.byKey(const Key('ai-note-task-creation-status')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Creation not confirmed'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('ai-note-task-edit-0')))
          .onPressed,
      isNull,
    );

    shouldFail = false;
    await tester.tap(find.byKey(const Key('ai-note-task-retry-create')));
    await tester.pumpAndSettle();

    expect(commands, hasLength(2));
    expect(identical(commands[0], commands[1]), isTrue);
    await tester.scrollUntilVisible(
      find.byKey(const Key('ai-note-task-creation-status')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('2 tasks created'), findsOneWidget);
    expect(repository.startedRequests, hasLength(1));
  });

  testWidgets('shows response diagnostics with task extraction recovery', (
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
    final diagnostic = AiDiagnostic(
      kind: AiDiagnosticKind.timeout,
      title: 'Endpoint timed out',
      summary: 'The endpoint did not respond before the configured timeout.',
      suggestions: const ['Check whether the model is still starting.'],
    );
    final repository = FakeAiAssistantRepository(
      responseEvents: [
        AiResponseFailed(
          error: TimeoutException('private duration'),
          message: diagnostic.summary,
          retryable: true,
          diagnostic: diagnostic,
        ),
      ],
    );
    final note = Quicxec(
      id: 'note-1',
      title: 'Weekend plan',
      text: 'Buy coffee.',
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
    await tester.tap(find.byKey(const Key('ai-note-task-send')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('ai-diagnostic-timeout')),
      200,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Endpoint timed out'), findsOneWidget);
    expect(
      find.text('• Check whether the model is still starting.'),
      findsOneWidget,
    );
    expect(find.textContaining('private duration'), findsNothing);
  });
}
