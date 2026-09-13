import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/repositories/note_repository.dart';
import 'package:provider/provider.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  final now = DateTime.utc(2026, 9, 13);
  final profile = AiConnectionProfile(
    id: 'home',
    name: 'Home AI',
    protocol: AiProtocol.openAiCompatibleChat,
    baseUrl: Uri.parse('https://ai.example.test/v1'),
    modelId: 'local-model',
  );
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
              content: 'Launch in October.',
              createdAt: now,
            ),
            AiChatMessage(
              id: 'assistant',
              role: AiMessageRole.assistant,
              content: 'Budget remains open.',
              createdAt: now,
            ),
          ],
        ),
      )!;

  Widget app({
    required FakeAiConnectionProfileStore profiles,
    required FakeAiAssistantRepository assistant,
    required AiConversationNoteCreateCallback onCreate,
    ValueChanged<Quicxec?>? onOpened,
  }) => MultiProvider(
    providers: [
      Provider<AiAssistantRepository>.value(value: assistant),
      Provider<AiConnectionProfileStore>.value(value: profiles),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder:
              (context) => FilledButton(
                onPressed: () async {
                  final result = await showAiConversationNoteSourcePreview(
                    context,
                    source: source,
                    profile: profile,
                    onCreate: onCreate,
                    creationIdFactory: () => 'fixed-id',
                    clock: () => now,
                  );
                  onOpened?.call(result);
                },
                child: const Text('Open'),
              ),
        ),
      ),
    ),
  );

  FakeAiAssistantRepository assistant() => FakeAiAssistantRepository(
    responseEvents: const [
      AiTextDelta(
        '{"schemaVersion":1,"note":{"title":"Launch plan","body":"Launch in October. Budget remains open."}}',
      ),
      AiResponseCompleted(),
    ],
  );

  Future<void> generate(WidgetTester tester) async {
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
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
  }

  testWidgets('edits and confirms final values before creating one note', (
    tester,
  ) async {
    final profiles = FakeAiConnectionProfileStore(
      profiles: [profile],
      activeProfileId: profile.id,
    );
    final commands = <CreateConversationNoteCommand>[];
    Quicxec? opened;
    addTearDown(profiles.dispose);
    await tester.pumpWidget(
      app(
        profiles: profiles,
        assistant: assistant(),
        onCreate: (command) async {
          commands.add(command);
          return command.toNote();
        },
        onOpened: (note) => opened = note,
      ),
    );
    await generate(tester);

    expect(commands, isEmpty);
    await tester.scrollUntilVisible(
      find.byKey(const Key('conversation-note-proposed-title')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const Key('conversation-note-proposed-title')),
      '  Revised plan  ',
    );
    await tester.enterText(
      find.byKey(const Key('conversation-note-proposed-body')),
      '  Decide a launch budget.  ',
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('conversation-note-save')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('conversation-note-save')));
    await tester.tap(find.byKey(const Key('conversation-note-save')));
    await tester.pumpAndSettle();

    expect(find.text('Create this note?'), findsOneWidget);
    expect(find.text('Revised plan'), findsOneWidget);
    expect(find.text('Decide a launch budget.'), findsOneWidget);
    expect(commands, isEmpty);
    await tester.tap(find.byKey(const Key('conversation-note-confirm-save')));
    await tester.pumpAndSettle();

    expect(commands, hasLength(1));
    expect(commands.single.title, 'Revised plan');
    expect(commands.single.body, 'Decide a launch budget.');
    expect(commands.single.sourceConversationId, 'conversation');
    expect(commands.single.sourceMessageIds, ['user', 'assistant']);
    expect(find.byKey(const Key('conversation-note-created')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('conversation-note-open')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('conversation-note-open')));
    await tester.drag(find.byType(ListView).last, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('conversation-note-open')));
    await tester.pumpAndSettle();
    expect(opened?.id, 'ai-note-fixed-id');
    expect(opened?.title, 'Revised plan');
    expect(
      AiNoteTaskPromptBuilder.build(
        noteTitle: opened!.title,
        noteContent: opened!.contentAsPlainText,
      ).userMessage,
      contains('Decide a launch budget.'),
    );
  });

  testWidgets('discard and cancelled confirmation do not create a note', (
    tester,
  ) async {
    final profiles = FakeAiConnectionProfileStore(
      profiles: [profile],
      activeProfileId: profile.id,
    );
    final commands = <CreateConversationNoteCommand>[];
    addTearDown(profiles.dispose);
    await tester.pumpWidget(
      app(
        profiles: profiles,
        assistant: assistant(),
        onCreate: (command) async {
          commands.add(command);
          return command.toNote();
        },
      ),
    );
    await generate(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('conversation-note-save')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('conversation-note-save')));
    await tester.tap(find.byKey(const Key('conversation-note-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to review'));
    await tester.pumpAndSettle();
    expect(commands, isEmpty);
    await tester.tap(find.byKey(const Key('conversation-note-close')));
    await tester.pumpAndSettle();
    expect(commands, isEmpty);
  });

  testWidgets('invalid edits cannot be saved', (tester) async {
    final profiles = FakeAiConnectionProfileStore(
      profiles: [profile],
      activeProfileId: profile.id,
    );
    final commands = <CreateConversationNoteCommand>[];
    addTearDown(profiles.dispose);
    await tester.pumpWidget(
      app(
        profiles: profiles,
        assistant: assistant(),
        onCreate: (command) async {
          commands.add(command);
          return command.toNote();
        },
      ),
    );
    await generate(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('conversation-note-proposed-title')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const Key('conversation-note-proposed-title')),
      '   ',
    );
    await tester.pumpAndSettle();
    expect(find.text('Enter a note title.'), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.byKey(const Key('conversation-note-save')),
    );
    expect(save.onPressed, isNull);
    expect(commands, isEmpty);
  });

  testWidgets('failed save retries the same confirmed command', (tester) async {
    final profiles = FakeAiConnectionProfileStore(
      profiles: [profile],
      activeProfileId: profile.id,
    );
    final commands = <CreateConversationNoteCommand>[];
    addTearDown(profiles.dispose);
    await tester.pumpWidget(
      app(
        profiles: profiles,
        assistant: assistant(),
        onCreate: (command) async {
          commands.add(command);
          if (commands.length == 1) throw StateError('Uncertain write');
          return command.toNote();
        },
      ),
    );
    await generate(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('conversation-note-save')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('conversation-note-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('conversation-note-confirm-save')));
    await tester.pumpAndSettle();
    expect(commands, hasLength(1));
    expect(
      find.byKey(const Key('conversation-note-create-error')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('conversation-note-retry-save')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.byKey(const Key('conversation-note-retry-save')),
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('conversation-note-retry-save')));
    await tester.pumpAndSettle();
    expect(commands, hasLength(2));
    expect(identical(commands.first, commands.last), isTrue);
    expect(find.byKey(const Key('conversation-note-created')), findsOneWidget);
  });

  testWidgets('in-flight save prevents another submission', (tester) async {
    final profiles = FakeAiConnectionProfileStore(
      profiles: [profile],
      activeProfileId: profile.id,
    );
    final pending = Completer<Quicxec>();
    final commands = <CreateConversationNoteCommand>[];
    addTearDown(profiles.dispose);
    await tester.pumpWidget(
      app(
        profiles: profiles,
        assistant: assistant(),
        onCreate: (command) {
          commands.add(command);
          return pending.future;
        },
      ),
    );
    await generate(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('conversation-note-save')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('conversation-note-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('conversation-note-confirm-save')));
    await tester.pump();

    expect(commands, hasLength(1));
    expect(find.byKey(const Key('conversation-note-save')), findsNothing);
    expect(find.byKey(const Key('conversation-note-retry-save')), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('conversation-note-close')))
          .onPressed,
      isNull,
    );
    pending.complete(commands.single.toNote());
    await tester.pumpAndSettle();
    expect(commands, hasLength(1));
    expect(find.byKey(const Key('conversation-note-created')), findsOneWidget);
  });
}
