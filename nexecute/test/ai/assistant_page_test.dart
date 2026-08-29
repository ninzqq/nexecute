import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  for (final preset in AppThemePreset.values) {
    testWidgets('renders the empty chat under the ${preset.name} theme', (
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
          assistantRepository: FakeAiAssistantRepository(),
          profileStore: profileStore,
          conversationStore: conversationStore,
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
    expect(find.text('Considering the options'), findsOneWidget);
    final saved = (await conversationStore.getConversations()).single;
    expect(saved.messages.last.content, 'The final answer');
    expect(saved.messages.last.content, isNot(contains('Considering')));
  });
}

Widget _app({
  required AiAssistantRepository assistantRepository,
  required AiConnectionProfileStore profileStore,
  required AiConversationStore conversationStore,
  ThemeData? theme,
}) {
  return MultiProvider(
    providers: [
      Provider<AiAssistantRepository>.value(value: assistantRepository),
      Provider<AiConnectionProfileStore>.value(value: profileStore),
      Provider<AiConversationStore>.value(value: conversationStore),
    ],
    child: MaterialApp(
      theme: theme,
      routes: {'/settings': (_) => const Scaffold(body: Text('Settings page'))},
      home: const AssistantPage(),
    ),
  );
}
