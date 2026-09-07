import 'package:flutter/foundation.dart';
import 'package:nexecute/ai/domain/ai_connection_result.dart';
import 'package:nexecute/ai/domain/ai_web_search.dart';
import 'package:nexecute/ai/repositories/ai_credential_store.dart';
import 'package:nexecute/ai/repositories/ai_web_search_connection_profile_store.dart';
import 'package:nexecute/ai/repositories/ai_web_search_repository.dart';
import 'package:uuid/uuid.dart';

final class AiWebSearchSettingsController extends ChangeNotifier {
  AiWebSearchSettingsController({
    required AiWebSearchConnectionProfileStore profileStore,
    required AiWebSearchRepository searchRepository,
    required AiCredentialStore credentialStore,
    String Function()? idFactory,
    this.isWeb = kIsWeb,
  }) : _profileStore = profileStore,
       _searchRepository = searchRepository,
       _credentialStore = credentialStore,
       _idFactory = idFactory ?? _newId;

  final AiWebSearchConnectionProfileStore _profileStore;
  final AiWebSearchRepository _searchRepository;
  final AiCredentialStore _credentialStore;
  final String Function() _idFactory;
  final bool isWeb;

  List<AiWebSearchConnectionProfile> _profiles = const [];
  AiWebSearchConnectionProfile? _activeProfile;
  bool _isLoading = true;
  Object? _loadError;
  String? _testingProfileId;
  String? _testedProfileId;
  AiConnectionResult? _connectionResult;
  bool _disposed = false;

  List<AiWebSearchConnectionProfile> get profiles => _profiles;
  AiWebSearchConnectionProfile? get activeProfile => _activeProfile;
  bool get isLoading => _isLoading;
  Object? get loadError => _loadError;
  String? get testingProfileId => _testingProfileId;
  String? get testedProfileId => _testedProfileId;
  AiConnectionResult? get connectionResult => _connectionResult;
  bool get credentialStorageAvailable => _credentialStore.isAvailable;
  bool get adapterAvailable => _searchRepository.isAvailable;

  String createProfileId() => _idFactory();

  Future<void> initialize() async {
    _isLoading = true;
    _loadError = null;
    _notify();
    try {
      await _reload();
    } catch (error) {
      _loadError = error;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> saveProfile(
    AiWebSearchConnectionProfile profile, {
    String? credential,
  }) async {
    final existing = _profileWithId(profile.id);
    final shouldActivate = _profiles.isEmpty;
    final oldReference =
        existing?.credentialReference ?? profile.credentialReference;
    final providerChanged =
        existing != null && existing.providerKind != profile.providerKind;
    final reusableReference = providerChanged ? null : oldReference;
    final normalizedCredential = credential?.trim();
    String? newReference;
    late final AiWebSearchConnectionProfile profileToSave;

    if (profile.provider.requiresCredential) {
      if (!_credentialStore.isAvailable) {
        throw const AiCredentialStoreException(
          'Secure search credentials are not available on this platform.',
        );
      }
      if (normalizedCredential?.isNotEmpty ?? false) {
        newReference = await _credentialStore.saveCredential(
          normalizedCredential!,
        );
        profileToSave = profile.copyWith(credentialReference: newReference);
      } else if (reusableReference != null) {
        profileToSave = profile.copyWith(
          credentialReference: reusableReference,
        );
      } else {
        throw const AiCredentialStoreException(
          'Enter an API key for this search connection.',
        );
      }
    } else {
      profileToSave = profile.copyWith(clearCredentialReference: true);
    }

    if (!profileToSave.isValid ||
        (profileToSave.enabled &&
            !profileToSave.canSendRequests(isWeb: isWeb))) {
      if (newReference != null) await _deleteCredentialBestEffort(newReference);
      throw const FormatException(
        'The web-search connection profile is incomplete or unavailable on '
        'this platform.',
      );
    }

    try {
      await _profileStore.saveProfile(profileToSave);
    } catch (_) {
      if (newReference != null) await _deleteCredentialBestEffort(newReference);
      rethrow;
    }
    if (oldReference != null &&
        (providerChanged ||
            !profile.provider.requiresCredential ||
            (newReference != null && newReference != oldReference))) {
      await _credentialStore.deleteCredential(oldReference);
    }
    if (shouldActivate) {
      await _profileStore.setActiveProfileId(profileToSave.id);
    }
    _clearResult(profileToSave.id);
    await _reloadAndNotify();
  }

  Future<void> deleteProfile(String profileId) async {
    final profile = _profileWithId(profileId);
    if (profile?.credentialReference case final reference?) {
      await _credentialStore.deleteCredential(reference);
    }
    await _profileStore.deleteProfile(profileId);
    _clearResult(profileId);
    await _reloadAndNotify();
  }

  Future<void> selectProfile(String profileId) async {
    await _profileStore.setActiveProfileId(profileId);
    await _reloadAndNotify();
  }

  Future<AiConnectionResult> testConnection(
    AiWebSearchConnectionProfile profile,
  ) async {
    if (!profile.canSendRequests(isWeb: isWeb)) {
      final result = AiConnectionResult(
        status: AiConnectionStatus.invalidConfiguration,
        message:
            isWeb
                ? 'Reusable search credentials are unavailable in the web app.'
                : 'Enable and complete this search connection first.',
      );
      _testedProfileId = profile.id;
      _connectionResult = result;
      _notify();
      return result;
    }
    _testingProfileId = profile.id;
    _testedProfileId = profile.id;
    _connectionResult = null;
    _notify();
    try {
      final result = await _searchRepository.testConnection(profile);
      _connectionResult = result;
      return result;
    } finally {
      _testingProfileId = null;
      _notify();
    }
  }

  Future<void> _reloadAndNotify() async {
    await _reload();
    _notify();
  }

  Future<void> _reload() async {
    _profiles = await _profileStore.getProfiles();
    _activeProfile = await _profileStore.getActiveProfile();
  }

  AiWebSearchConnectionProfile? _profileWithId(String id) {
    for (final profile in _profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  Future<void> _deleteCredentialBestEffort(String reference) async {
    try {
      await _credentialStore.deleteCredential(reference);
    } catch (_) {}
  }

  void _clearResult(String id) {
    if (_testedProfileId == id) {
      _testedProfileId = null;
      _connectionResult = null;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static String _newId() => const Uuid().v4();
}
