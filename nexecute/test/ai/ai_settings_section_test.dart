import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  testWidgets('adds, activates, discovers models, and tests a connection', (
    tester,
  ) async {
    final store = FakeAiConnectionProfileStore();
    final repository = FakeAiAssistantRepository(
      connectionResult: const AiConnectionResult.connected(message: 'Ready'),
      models: [AiModelInfo(id: 'qwen3:8b')],
    );
    addTearDown(store.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AiConnectionProfileStore>.value(value: store),
          Provider<AiAssistantRepository>.value(value: repository),
        ],
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: AiSettingsSection(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('No AI connection is configured.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('ai-add-profile')));
    await tester.pumpAndSettle();

    final generationControls = tester.widget<ExpansionTile>(
      find.byKey(const Key('ai-generation-controls')),
    );
    expect(
      generationControls.childrenPadding,
      const EdgeInsets.only(top: 12, bottom: 8),
    );
    expect(generationControls.shape, const Border());
    expect(generationControls.collapsedShape, const Border());

    await tester.enterText(
      find.byKey(const Key('ai-profile-name-field')),
      'Home Ollama',
    );
    await tester.enterText(
      find.byKey(const Key('ai-profile-url-field')),
      'https://ai.example.test/v1',
    );
    await tester.tap(find.byKey(const Key('ai-discover-models')));
    await tester.pumpAndSettle();

    expect(find.text('1 model available.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('ai-profile-model-field')),
      'qwen3:8b',
    );
    await tester.ensureVisible(
      find.byKey(const Key('ai-profile-reasoning-field')),
    );
    await tester.tap(find.byKey(const Key('ai-profile-reasoning-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Low').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ai-profile-max-output-tokens-field')),
      '2048',
    );
    await tester.enterText(
      find.byKey(const Key('ai-profile-connection-timeout-field')),
      '180',
    );
    await tester.enterText(
      find.byKey(const Key('ai-profile-stream-timeout-field')),
      '60',
    );
    await tester.tap(find.byKey(const Key('ai-profile-save')));
    await tester.pumpAndSettle();

    expect(find.text('Home Ollama'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(repository.listedProfiles, hasLength(1));

    final profile = (await store.getProfiles()).single;
    expect(profile.reasoningEffort, AiReasoningEffort.low);
    expect(profile.maxOutputTokens, 2048);
    expect(profile.connectionTimeout, const Duration(seconds: 180));
    expect(profile.responseIdleTimeout, const Duration(seconds: 60));
    await tester.tap(find.byKey(Key('ai-profile-test-${profile.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Ready'), findsOneWidget);
    expect(repository.testedProfiles.single.id, profile.id);

    await tester.tap(
      find.descendant(
        of: find.byKey(Key('ai-profile-${profile.id}')),
        matching: find.byTooltip('AI connection actions'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();

    expect(find.text('Home Ollama copy'), findsOneWidget);
    final duplicate = (await store.getProfiles()).last;
    await tester.tap(
      find.descendant(
        of: find.byKey(Key('ai-profile-${duplicate.id}')),
        matching: find.text('Use this connection'),
      ),
    );
    await tester.pumpAndSettle();
    expect((await store.getActiveProfile())?.id, duplicate.id);

    await tester.tap(
      find.descendant(
        of: find.byKey(Key('ai-profile-${duplicate.id}')),
        matching: find.byTooltip('AI connection actions'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Home Ollama copy'), findsNothing);
  });

  testWidgets('shows plain HTTP guidance while editing a profile', (
    tester,
  ) async {
    final store = FakeAiConnectionProfileStore();
    final repository = FakeAiAssistantRepository();
    addTearDown(store.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AiConnectionProfileStore>.value(value: store),
          Provider<AiAssistantRepository>.value(value: repository),
        ],
        child: const MaterialApp(home: Scaffold(body: AiSettingsSection())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-add-profile')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('ai-profile-url-field')),
      'http://localhost:11434/v1',
    );
    await tester.pump();

    expect(find.textContaining('Plain HTTP exposes prompts'), findsOneWidget);
    expect(
      find.textContaining('localhost points to this device'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('ai-profile-max-output-tokens-field')),
      '0',
    );
    await tester.tap(find.byKey(const Key('ai-profile-save')));
    await tester.pump();

    expect(find.text('Use a value from 1 to 131072.'), findsOneWidget);
  });
}
