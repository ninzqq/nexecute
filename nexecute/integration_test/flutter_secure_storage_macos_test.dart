import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('saves, replaces, and deletes credentials in macOS Keychain', (
    tester,
  ) async {
    final references = <String>[];
    final store = FlutterSecureAiCredentialStore.macOS();
    addTearDown(() async {
      for (final reference in references) {
        await store.deleteCredential(reference);
      }
    });

    final originalReference = await store.saveCredential(
      'nexecute-macos-keychain-smoke-original',
    );
    references.add(originalReference);
    expect(
      await store.readCredential(originalReference),
      'nexecute-macos-keychain-smoke-original',
    );

    final replacementReference = await store.saveCredential(
      'nexecute-macos-keychain-smoke-replacement',
    );
    references.add(replacementReference);
    expect(replacementReference, isNot(originalReference));

    await store.deleteCredential(originalReference);
    references.remove(originalReference);
    expect(await store.readCredential(originalReference), isNull);
    expect(
      await store.readCredential(replacementReference),
      'nexecute-macos-keychain-smoke-replacement',
    );

    await store.deleteCredential(replacementReference);
    references.remove(replacementReference);
    expect(await store.readCredential(replacementReference), isNull);
  });
}
