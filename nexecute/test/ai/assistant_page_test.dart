import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  for (final preset in AppThemePreset.values) {
    testWidgets('renders context fallback under the ${preset.name} theme', (
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
      final conversationStore = FakeAiConversationStore();
      final assistantRepository = FakeAiAssistantRepository();
      final contextService = FakeAiApplicationContextReadService();
      contextService.tasksContext = AiApplicationContextEnvelope(
        generatedAt: DateTime.utc(2026, 8, 30),
        attachments: [
          AiActiveTasksContextAttachment(
            tasks: const [
              AiTaskContextItem(
                title: 'Theme-safe attached task',
                isCompleted: false,
              ),
            ],
            omittedCount: 0,
          ),
        ],
      );
      addTearDown(profileStore.dispose);
      addTearDown(conversationStore.dispose);

      await tester.pumpWidget(
        _app(
          assistantRepository: assistantRepository,
          profileStore: profileStore,
          conversationStore: conversationStore,
          contextReadService: contextService,
          theme: AppThemes.forPreset(preset),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start a conversation'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('assistant-composer')))
            .textCapitalization,
        TextCapitalization.sentences,
      );

      await tester.tap(find.byKey(const Key('assistant-attach-context')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unfinished tasks'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('assistant-task-context')), findsOneWidget);

      await tester.tap(find.byKey(const Key('assistant-preview-context')));
      await tester.pumpAndSettle();
      final preview =
          tester
              .widget<SelectableText>(
                find.byKey(const Key('assistant-context-preview-json')),
              )
              .data!;
      expect(preview, contains('Theme-safe attached task'));
      expect(
        preview,
        contains('"dataClassification":"untrustedApplicationData"'),
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('assistant-composer')),
        'Use the attached task',
      );
      await tester.tap(find.byKey(const Key('assistant-send')));
      await tester.pumpAndSettle();

      final request = assistantRepository.startedRequests.single;
      expect(request.applicationContext!.encode(), preview);
      expect(request.toolDefinitions, isEmpty);
      final saved = (await conversationStore.getConversations()).single;
      expect(
        saved.messages.any((message) => message.content.contains('Theme-safe')),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows setup guidance without an active connection', (
    tester,
  ) async {
    final profileStore = FakeAiConnectionProfileStore();
    final conversationStore = FakeAiConversationStore();
    addTearDown(profileStore.dispose);
    addTearDown(conversationStore.dispose);

    await tester.pumpWidget(
      _app(
        assistantRepository: FakeAiAssistantRepository(),
        profileStore: profileStore,
        conversationStore: conversationStore,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connect an AI endpoint'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('assistant-send')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('constrains assistant content in a wide desktop window', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final profileStore = FakeAiConnectionProfileStore();
    final conversationStore = FakeAiConversationStore();
    addTearDown(profileStore.dispose);
    addTearDown(conversationStore.dispose);

    await tester.pumpWidget(
      _app(
        assistantRepository: FakeAiAssistantRepository(),
        profileStore: profileStore,
        conversationStore: conversationStore,
      ),
    );
    await tester.pumpAndSettle();

    final contentRect = tester.getRect(
      find.byKey(const Key('assistant-content-frame')),
    );
    expect(contentRect.width, 840);
    expect(contentRect.center.dx, 700);
    expect(tester.takeException(), isNull);
  });

  testWidgets('focuses and sends from the composer with desktop shortcuts', (
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
    final conversationStore = FakeAiConversationStore();
    final assistantRepository = FakeAiAssistantRepository();
    addTearDown(profileStore.dispose);
    addTearDown(conversationStore.dispose);

    await tester.pumpWidget(
      _app(
        assistantRepository: assistantRepository,
        profileStore: profileStore,
        conversationStore: conversationStore,
      ),
    );
    await tester.pumpAndSettle();

    final composer = find.byKey(const Key('assistant-composer'));
    expect(tester.widget<TextField>(composer).focusNode!.hasFocus, isFalse);

    await _pressControlShiftShortcut(tester, LogicalKeyboardKey.keyA);
    expect(tester.widget<TextField>(composer).focusNode!.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(tester.widget<TextField>(composer).focusNode!.hasFocus, isFalse);

    await _pressControlShiftShortcut(tester, LogicalKeyboardKey.keyA);

    await tester.enterText(composer, 'Send from the keyboard');
    await _pressControlShortcut(tester, LogicalKeyboardKey.enter);

    expect(assistantRepository.startedRequests, hasLength(1));
    expect(
      assistantRepository.startedRequests.single.messages.last.content,
      'Send from the keyboard',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sends a message and displays streamed assistant text', (
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
    final conversationStore = FakeAiConversationStore();
    addTearDown(profileStore.dispose);
    addTearDown(conversationStore.dispose);

    await tester.pumpWidget(
      _app(
        assistantRepository: FakeAiAssistantRepository(
          responseEvents: const [
            AiTextDelta('A helpful answer'),
            AiResponseCompleted(),
          ],
        ),
        profileStore: profileStore,
        conversationStore: conversationStore,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home AI · local-model'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('assistant-composer')),
      'Hello assistant',
    );
    await tester.tap(find.byKey(const Key('assistant-send')));
    await tester.pumpAndSettle();

    expect(find.text('Hello assistant'), findsOneWidget);
    expect(find.text('A helpful answer'), findsOneWidget);
    expect((await conversationStore.getConversations()), hasLength(1));

    await tester.tap(find.byKey(const Key('assistant-conversation-list')));
    await tester.pumpAndSettle();
    expect(find.text('Conversations'), findsOneWidget);
    expect(find.text('Hello assistant'), findsNWidgets(2));
  });

  testWidgets('shows streamed reasoning without persisting it', (tester) async {
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
    final conversationStore = FakeAiConversationStore();
    final responseStream = StreamController<AiStreamEvent>();
    addTearDown(profileStore.dispose);
    addTearDown(conversationStore.dispose);
    addTearDown(responseStream.close);

    await tester.pumpWidget(
      _app(
        assistantRepository: FakeAiAssistantRepository(
          responseStreamBuilder: (_) => responseStream.stream,
        ),
        profileStore: profileStore,
        conversationStore: conversationStore,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('assistant-composer')),
      'Think about this',
    );
    await tester.tap(find.byKey(const Key('assistant-send')));
    await tester.pump();

    responseStream.add(const AiReasoningDelta('Considering the options'));
    await tester.pump();

    expect(find.text('Reasoning'), findsOneWidget);
    expect(find.text('Session only · not synchronized'), findsOneWidget);
    expect(find.text('Considering the options'), findsOneWidget);

    responseStream.add(const AiTextDelta('The final answer'));
    responseStream.add(const AiResponseCompleted());
    await tester.pumpAndSettle();

    expect(find.text('The final answer'), findsOneWidget);
    expect(find.text('Considering the options'), findsNothing);

    await tester.tap(find.text('Reasoning'));
    await tester.pumpAndSettle();

    expect(find.text('Considering the options'), findsOneWidget);
    final saved = (await conversationStore.getConversations()).single;
    expect(saved.messages.last.content, 'The final answer');
    expect(saved.messages.last.content, isNot(contains('Considering')));
  });

  testWidgets(
    'previews exact task context, sends it once, and excludes it from history',
    (tester) async {
      final profile = AiConnectionProfile(
        id: 'home',
        name: 'Home AI',
        protocol: AiProtocol.openAiCompatibleChat,
        baseUrl: Uri.parse('https://ai.example.test/v1'),
        modelId: 'local-model',
        capabilityOverrides: const {AiCapability.tools: true},
      );
      final profileStore = FakeAiConnectionProfileStore(
        profiles: [profile],
        activeProfileId: profile.id,
      );
      final conversationStore = FakeAiConversationStore();
      final assistantRepository = FakeAiAssistantRepository();
      final contextService = FakeAiApplicationContextReadService();
      contextService.tasksContext = AiApplicationContextEnvelope(
        generatedAt: DateTime.utc(2026, 8, 29),
        attachments: [
          AiActiveTasksContextAttachment(
            tasks: const [
              AiTaskContextItem(title: 'Finish roadmap', isCompleted: false),
            ],
            omittedCount: 2,
          ),
        ],
      );
      addTearDown(profileStore.dispose);
      addTearDown(conversationStore.dispose);

      await tester.pumpWidget(
        _app(
          assistantRepository: assistantRepository,
          profileStore: profileStore,
          conversationStore: conversationStore,
          contextReadService: contextService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('assistant-attach-context')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unfinished tasks'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('assistant-task-context')), findsOneWidget);

      await tester.tap(find.byKey(const Key('assistant-preview-context')));
      await tester.pumpAndSettle();
      final preview =
          tester
              .widget<SelectableText>(
                find.byKey(const Key('assistant-context-preview-json')),
              )
              .data!;
      expect(preview, contains('Finish roadmap'));
      expect(preview, contains('"omittedCount":2'));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('assistant-composer')),
        'Summarize my work',
      );
      await tester.tap(find.byKey(const Key('assistant-send')));
      await tester.pumpAndSettle();

      expect(assistantRepository.startedRequests, hasLength(1));
      expect(
        assistantRepository.startedRequests.single.applicationContext!.encode(),
        preview,
      );
      expect(
        assistantRepository.startedRequests.single.toolDefinitions.map(
          (tool) => tool.name,
        ),
        [AiReadToolNames.listTasks],
      );
      expect(find.byKey(const Key('assistant-task-context')), findsNothing);
      final saved = (await conversationStore.getConversations()).single;
      expect(
        saved.messages.any(
          (message) => message.content.contains('Finish roadmap'),
        ),
        isFalse,
      );
    },
  );

  testWidgets('retains attached context when the request cannot start', (
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
    final conversationStore = FakeAiConversationStore();
    final contextService = FakeAiApplicationContextReadService();
    contextService.tasksContext = AiApplicationContextEnvelope(
      generatedAt: DateTime.utc(2026, 8, 29),
      attachments: [
        AiActiveTasksContextAttachment(
          tasks: const [
            AiTaskContextItem(title: 'Keep me', isCompleted: false),
          ],
          omittedCount: 0,
        ),
      ],
    );
    addTearDown(profileStore.dispose);
    addTearDown(conversationStore.dispose);

    await tester.pumpWidget(
      _app(
        assistantRepository: FakeAiAssistantRepository(
          startResponseError: StateError('offline'),
        ),
        profileStore: profileStore,
        conversationStore: conversationStore,
        contextReadService: contextService,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-attach-context')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unfinished tasks'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('assistant-composer')),
      'Try to send',
    );
    await tester.tap(find.byKey(const Key('assistant-send')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('assistant-task-context')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('assistant-composer')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('shows actionable diagnostics for failed chat responses', (
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
    final conversationStore = FakeAiConversationStore();
    final diagnostic = AiDiagnostic(
      kind: AiDiagnosticKind.dns,
      title: 'Host not found',
      summary: 'The endpoint name could not be resolved.',
      suggestions: const ['Check the endpoint address in AI Settings.'],
    );
    addTearDown(profileStore.dispose);
    addTearDown(conversationStore.dispose);

    await tester.pumpWidget(
      _app(
        assistantRepository: FakeAiAssistantRepository(
          responseEvents: [
            AiResponseFailed(
              error: StateError('private host detail'),
              message: diagnostic.summary,
              retryable: true,
              diagnostic: diagnostic,
            ),
          ],
        ),
        profileStore: profileStore,
        conversationStore: conversationStore,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('assistant-composer')),
      'Hello',
    );
    await tester.tap(find.byKey(const Key('assistant-send')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-diagnostic-dns')), findsOneWidget);
    expect(find.text('Host not found'), findsOneWidget);
    expect(
      find.text('• Check the endpoint address in AI Settings.'),
      findsOneWidget,
    );
    expect(find.textContaining('private host detail'), findsNothing);
    expect(find.byKey(const Key('assistant-retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai-diagnostic-action-dns')));
    await tester.pumpAndSettle();
    expect(find.text('Settings page'), findsOneWidget);

    Navigator.of(tester.element(find.text('Settings page'))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assistant-retry')), findsOneWidget);
  });

  testWidgets('selects persistent skills and previews only source metadata', (
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
    final conversationStore = FakeAiConversationStore();
    final repository = FakeAiAssistantRepository();
    final skill = _skill('suomen-kieli', 'Private Finnish instructions');
    final disabled = _skill(
      'disabled-skill',
      'Private disabled instructions',
    ).copyWith(isEnabled: false);
    final skillStore = InMemoryAiSkillStore(skills: [skill, disabled]);
    final preferences = InMemoryAiSkillPreferencesStore();
    addTearDown(profileStore.dispose);
    addTearDown(conversationStore.dispose);
    addTearDown(skillStore.dispose);
    addTearDown(preferences.dispose);

    await tester.pumpWidget(
      _app(
        assistantRepository: repository,
        profileStore: profileStore,
        conversationStore: conversationStore,
        skillStore: skillStore,
        skillPreferencesStore: preferences,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Skills · none active'), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant-pick-skills')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Inactive · Finnish writing'), findsOneWidget);
    expect(find.textContaining('Disabled · Finnish writing'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('assistant-skill-option-suomen-kieli')),
    );
    await tester.tap(find.byKey(const Key('assistant-skill-apply')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('assistant-skill-suomen-kieli')),
      findsOneWidget,
    );
    expect(find.text('Active skills for this conversation'), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant-preview-instructions')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Active skill · Suomen kieli'), findsOneWidget);
    expect(find.textContaining(skill.instructions), findsNothing);
    expect(
      find.textContaining('excludes credentials, skill bodies'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('assistant-composer')),
      'Kirjoita tervehdys',
    );
    await tester.tap(find.byKey(const Key('assistant-send')));
    await tester.pumpAndSettle();

    expect(
      repository.startedRequests.single.resolvedSkills.single.id,
      skill.id,
    );
    expect((await conversationStore.getConversations()).single.activeSkills, [
      AiSkillReference.fromSkill(skill),
    ]);
  });

  testWidgets(
    'shows changed skill recovery and requires explicit continuation',
    (tester) async {
      final profile = AiConnectionProfile(
        id: 'home',
        name: 'Home AI',
        protocol: AiProtocol.openAiCompatibleChat,
        baseUrl: Uri.parse('https://ai.example.test/v1'),
        modelId: 'local-model',
      );
      final previous = _skill('review', 'Previous private instructions');
      final current = _skill('review', 'Current private instructions');
      final conversation = AiConversation(
        id: 'conversation',
        title: 'Review',
        connectionProfileId: profile.id,
        modelId: profile.modelId,
        createdAt: DateTime.utc(2026, 9, 5),
        updatedAt: DateTime.utc(2026, 9, 5),
        activeSkills: [AiSkillReference.fromSkill(previous)],
      );
      final profileStore = FakeAiConnectionProfileStore(
        profiles: [profile],
        activeProfileId: profile.id,
      );
      final conversationStore = FakeAiConversationStore(
        conversations: [conversation],
      );
      final repository = FakeAiAssistantRepository();
      final skillStore = InMemoryAiSkillStore(skills: [current]);
      addTearDown(profileStore.dispose);
      addTearDown(conversationStore.dispose);
      addTearDown(skillStore.dispose);

      await tester.pumpWidget(
        _app(
          assistantRepository: repository,
          profileStore: profileStore,
          conversationStore: conversationStore,
          skillStore: skillStore,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('review · changed'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('assistant-composer')),
        'Continue explicitly',
      );
      await tester.tap(find.byKey(const Key('assistant-send')));
      await tester.pumpAndSettle();

      expect(find.text('Active skills need attention'), findsOneWidget);
      expect(find.textContaining('local revision changed'), findsOneWidget);
      expect(repository.startedRequests, isEmpty);
      await tester.tap(
        find.byKey(const Key('assistant-continue-without-skills')),
      );
      await tester.pumpAndSettle();

      expect(repository.startedRequests.single.resolvedSkills, isEmpty);
      expect(
        (await conversationStore.getConversations()).single.activeSkills.single,
        AiSkillReference.fromSkill(previous),
      );
      expect(find.textContaining(previous.instructions), findsNothing);
      expect(find.textContaining(current.instructions), findsNothing);
    },
  );
}

Widget _app({
  required AiAssistantRepository assistantRepository,
  required AiConnectionProfileStore profileStore,
  required AiConversationStore conversationStore,
  AiApplicationContextReadService? contextReadService,
  AiSkillStore? skillStore,
  AiSkillPreferencesStore? skillPreferencesStore,
  ThemeData? theme,
}) {
  return MultiProvider(
    providers: [
      Provider<AiAssistantRepository>.value(value: assistantRepository),
      Provider<AiConnectionProfileStore>.value(value: profileStore),
      Provider<AiConversationStore>.value(value: conversationStore),
      if (skillStore != null) Provider<AiSkillStore>.value(value: skillStore),
      if (skillPreferencesStore != null)
        Provider<AiSkillPreferencesStore>.value(value: skillPreferencesStore),
      Provider<AiApplicationContextReadService>(
        create:
            (_) => contextReadService ?? FakeAiApplicationContextReadService(),
      ),
    ],
    child: MaterialApp(
      theme: theme,
      routes: {'/settings': (_) => const Scaffold(body: Text('Settings page'))},
      home: const AssistantPage(),
    ),
  );
}

AiSkill _skill(String id, String instructions) => AiSkill(
  id: id,
  name: id == 'suomen-kieli' ? 'Suomen kieli' : id,
  description: 'Finnish writing',
  instructions: instructions,
  createdAt: DateTime.utc(2026, 9, 5),
  updatedAt: DateTime.utc(2026, 9, 5),
);

Future<void> _pressControlShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Future<void> _pressControlShiftShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}
