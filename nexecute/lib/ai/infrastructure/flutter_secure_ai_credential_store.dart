import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nexecute/ai/repositories/ai_credential_store.dart';
import 'package:uuid/uuid.dart';

class FlutterSecureAiCredentialStore implements AiCredentialStore {
  FlutterSecureAiCredentialStore({
    FlutterSecureStorage? storage,
    String Function()? referenceFactory,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _referenceFactory = referenceFactory ?? _newReference;

  static const _referencePrefix = 'secure-storage:';
  static const _storageKeyPrefix = 'nexecute.ai.credential.';

  final FlutterSecureStorage _storage;
  final String Function() _referenceFactory;

  @override
  bool get isAvailable => true;

  @override
  Future<String> saveCredential(String credential) async {
    final normalized = credential.trim();
    if (normalized.isEmpty || normalized.length > aiMaxCredentialCharacters) {
      throw const AiCredentialStoreException(
        'The endpoint credential is empty or too long.',
      );
    }

    final reference = _referenceFactory();
    try {
      await _storage.write(key: _storageKey(reference), value: normalized);
      return reference;
    } catch (_) {
      throw const AiCredentialStoreException(
        'Could not save the endpoint credential securely on this device.',
      );
    }
  }

  @override
  Future<String?> readCredential(String reference) async {
    try {
      return await _storage.read(key: _storageKey(reference));
    } catch (_) {
      throw const AiCredentialStoreException(
        'Could not access the endpoint credential on this device.',
      );
    }
  }

  @override
  Future<void> deleteCredential(String reference) async {
    try {
      await _storage.delete(key: _storageKey(reference));
    } catch (_) {
      throw const AiCredentialStoreException(
        'Could not remove the endpoint credential from this device.',
      );
    }
  }

  static String _storageKey(String reference) {
    if (!reference.startsWith(_referencePrefix) ||
        reference.length == _referencePrefix.length) {
      throw const AiCredentialStoreException(
        'The endpoint credential reference is invalid.',
      );
    }
    return '$_storageKeyPrefix${reference.substring(_referencePrefix.length)}';
  }

  static String _newReference() => '$_referencePrefix${const Uuid().v4()}';
}

class UnavailableAiCredentialStore implements AiCredentialStore {
  const UnavailableAiCredentialStore();

  @override
  bool get isAvailable => false;

  @override
  Future<String> saveCredential(String credential) =>
      throw const AiCredentialStoreException(
        'Secure endpoint credentials are not available on this platform.',
      );

  @override
  Future<String?> readCredential(String reference) =>
      throw const AiCredentialStoreException(
        'Secure endpoint credentials are not available on this platform.',
      );

  @override
  Future<void> deleteCredential(String reference) =>
      throw const AiCredentialStoreException(
        'Secure endpoint credentials are not available on this platform.',
      );
}
