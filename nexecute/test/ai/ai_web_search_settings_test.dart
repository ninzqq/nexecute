import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:provider/provider.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  testWidgets('saves an enabled Brave profile with a secure key reference', (
    tester,
  ) async {
    final profiles = InMemoryAiWebSearchConnectionProfileStore();
    final credentials = FakeAiCredentialStore();
    addTearDown(profiles.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AiWebSearchConnectionProfileStore>.value(value: profiles),
          Provider<AiWebSearchRepository>.value(
            value: const UnavailableAiWebSearchRepository(),
          ),
          Provider<AiCredentialStore>.value(value: credentials),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: AiWebSearchSettings(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('ai-web-search-adapter-unavailable')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('ai-add-web-search-connection')));
    await tester.pumpAndSettle();

    expect(find.text('Brave Search API'), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('ai-web-search-url-field')),
              matching: find.byType(EditableText),
            ),
          )
          .readOnly,
      isTrue,
    );
    await tester.enterText(
      find.byKey(const Key('ai-web-search-api-key-field')),
      'brave-key',
    );
    await tester.ensureVisible(
      find.byKey(const Key('ai-web-search-enabled-field')),
    );
    await tester.tap(find.byKey(const Key('ai-web-search-enabled-field')));
    await tester.ensureVisible(find.byKey(const Key('ai-web-search-save')));
    await tester.tap(find.byKey(const Key('ai-web-search-save')));
    await tester.pumpAndSettle();

    final saved = (await profiles.getProfiles()).single;
    expect(saved.enabled, isTrue);
    expect(saved.providerKind, AiWebSearchProviderKind.brave);
    expect(saved.baseUrl, AiWebSearchProviderCatalog.brave.trustedBaseUri);
    expect(saved.credentialReference, isNotNull);
    expect(credentials.savedCredentials, ['brave-key']);
  });
}
