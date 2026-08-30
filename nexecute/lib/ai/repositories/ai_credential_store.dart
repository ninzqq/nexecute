const aiMaxCredentialCharacters = 8192;

abstract interface class AiCredentialStore {
  bool get isAvailable;

  Future<String> saveCredential(String credential);

  Future<String?> readCredential(String reference);

  Future<void> deleteCredential(String reference);
}

class AiCredentialStoreException implements Exception {
  const AiCredentialStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}
