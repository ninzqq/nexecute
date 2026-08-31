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
          Provider<AiCredentialStore>.value(value: FakeAiCredentialStore()),
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
    await tester.ensureVisible(
      find.byKey(const Key('ai-system-prompt-controls')),
    );
    await tester.tap(find.byKey(const Key('ai-system-prompt-controls')));
    await tester.pumpAndSettle();
    final systemPromptField = find.byKey(
      const Key('ai-profile-system-prompt-field'),
    );
    await tester.ensureVisible(systemPromptField);
    final systemPromptWidget = tester.widget<TextFormField>(systemPromptField);
    expect(systemPromptWidget.controller?.text, aiDefaultSystemPrompt);
    await tester.enterText(systemPromptField, 'Answer in concise Finnish.');
    await tester.ensureVisible(find.byKey(const Key('ai-capability-controls')));
    await tester.tap(find.byKey(const Key('ai-capability-controls')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('ai-profile-capability-reasoning-field')),
    );
    await tester.tap(
      find.byKey(const Key('ai-profile-capability-reasoning-field')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supported').last);
    await tester.pumpAndSettle();
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
    expect(profile.systemPrompt, 'Answer in concise Finnish.');
    expect(profile.capabilityOverrides[AiCapability.reasoning], isTrue);
    expect(find.textContaining('Confirmed: Reasoning'), findsOneWidget);
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
          Provider<AiCredentialStore>.value(value: FakeAiCredentialStore()),
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

  testWidgets('shows actionable guidance after a failed connection test', (
    tester,
  ) async {
    final profile = AiConnectionProfile(
      id: 'home',
      name: 'Home AI',
      protocol: AiProtocol.openAiCompatibleChat,
      baseUrl: Uri.parse('https://ai.example.test/v1'),
      modelId: 'local-model',
    );
    final diagnostic = AiDiagnostic(
      kind: AiDiagnosticKind.authentication,
      title: 'Authentication failed',
      summary: 'The endpoint rejected the configured authentication.',
      suggestions: const ['Check the credential in AI Settings.'],
    );
    final store = FakeAiConnectionProfileStore(
      profiles: [profile],
      activeProfileId: profile.id,
    );
    addTearDown(store.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AiConnectionProfileStore>.value(value: store),
          Provider<AiCredentialStore>.value(value: FakeAiCredentialStore()),
          Provider<AiAssistantRepository>.value(
            value: FakeAiAssistantRepository(
              connectionResult: AiConnectionResult(
                status: AiConnectionStatus.authenticationFailed,
                message: diagnostic.summary,
                diagnostic: diagnostic,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: AiSettingsSection())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-profile-test-home')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('ai-diagnostic-authentication')),
      findsOneWidget,
    );
    expect(find.text('Authentication failed'), findsOneWidget);
    expect(find.text('• Check the credential in AI Settings.'), findsOneWidget);
    expect(
      find.byKey(const Key('ai-diagnostic-action-authentication')),
      findsNothing,
    );
  });

  testWidgets('saves a bearer token outside the connection profile', (
    tester,
  ) async {
    final store = FakeAiConnectionProfileStore();
    final credentialStore = FakeAiCredentialStore();
    addTearDown(store.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AiConnectionProfileStore>.value(value: store),
          Provider<AiCredentialStore>.value(value: credentialStore),
          Provider<AiAssistantRepository>.value(
            value: FakeAiAssistantRepository(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: AiSettingsSection())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-add-profile')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('ai-profile-name-field')),
      'Private gateway',
    );
    await tester.enterText(
      find.byKey(const Key('ai-profile-url-field')),
      'https://gateway.example.test/v1',
    );
    await tester.enterText(
      find.byKey(const Key('ai-profile-model-field')),
      'model-private',
    );
    final authField = find.byKey(const Key('ai-profile-auth-field'));
    await tester.ensureVisible(authField);
    await tester.tap(authField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bearer token').last);
    await tester.pumpAndSettle();

    final tokenField = find.byKey(const Key('ai-profile-bearer-token-field'));
    await tester.ensureVisible(tokenField);
    await tester.enterText(tokenField, 'widget-private-token');
    await tester.ensureVisible(find.byKey(const Key('ai-profile-save')));
    await tester.tap(find.byKey(const Key('ai-profile-save')));
    await tester.pumpAndSettle();

    final profile = (await store.getProfiles()).single;
    expect(profile.authenticationMode, AiAuthenticationMode.bearerToken);
    expect(profile.credentialReference, startsWith('secure-storage:'));
    expect(credentialStore.savedCredentials, ['widget-private-token']);
    expect(find.text('widget-private-token'), findsNothing);
  });
}
