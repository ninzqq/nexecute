import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final values = <String, String>{};
  Map<Object?, Object?>? lastOptions;

  setUp(() {
    values.clear();
    lastOptions = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final arguments = Map<Object?, Object?>.from(call.arguments as Map);
          lastOptions = Map<Object?, Object?>.from(arguments['options'] as Map);
          final key = arguments['key'] as String?;
          switch (call.method) {
            case 'write':
              values[key!] = arguments['value'] as String;
              return null;
            case 'read':
              return values[key];
            case 'delete':
              values.remove(key);
              return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('maps opaque references to secure storage keys', () async {
    final store = FlutterSecureAiCredentialStore(
      referenceFactory: () => 'secure-storage:fixed-reference',
    );

    final reference = await store.saveCredential('  private-token  ');

    expect(reference, 'secure-storage:fixed-reference');
    expect(values, {'nexecute.ai.credential.fixed-reference': 'private-token'});
    expect(await store.readCredential(reference), 'private-token');

    await store.deleteCredential(reference);

    expect(values, isEmpty);
  });

  test('rejects invalid references without exposing the credential', () async {
    final store = FlutterSecureAiCredentialStore(
      referenceFactory: () => 'invalid-reference',
    );

    Object? error;
    try {
      await store.saveCredential('secret-value');
    } catch (caught) {
      error = caught;
    }

    expect(error, isA<AiCredentialStoreException>());
    expect(error.toString(), isNot(contains('secret-value')));
    expect(values, isEmpty);
  });

  test('uses device-local macOS Keychain options', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final store = FlutterSecureAiCredentialStore.macOS(
      referenceFactory: () => 'secure-storage:macos-reference',
    );

    await store.saveCredential('private-token');

    expect(
      lastOptions,
      containsPair('accountName', 'com.jndevworks.nexecute.ai-credentials'),
    );
    expect(lastOptions, containsPair('accessibility', 'unlocked_this_device'));
    expect(lastOptions, containsPair('synchronizable', 'false'));
    expect(lastOptions, containsPair('usesDataProtectionKeychain', 'true'));
  });
}
