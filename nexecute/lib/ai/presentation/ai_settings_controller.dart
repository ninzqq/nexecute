import 'package:flutter/foundation.dart';
import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/ai/domain/ai_connection_result.dart';
import 'package:nexecute/ai/domain/ai_model_info.dart';
import 'package:nexecute/ai/domain/ai_protocol.dart';
import 'package:nexecute/ai/repositories/ai_assistant_repository.dart';
import 'package:nexecute/ai/repositories/ai_connection_profile_store.dart';
import 'package:nexecute/ai/repositories/ai_credential_store.dart';
import 'package:uuid/uuid.dart';

class AiSettingsController extends ChangeNotifier {
  AiSettingsController({
    required AiConnectionProfileStore profileStore,
    required AiAssistantRepository assistantRepository,
    required AiCredentialStore credentialStore,
    String Function()? idFactory,
  }) : _profileStore = profileStore,
       _assistantRepository = assistantRepository,
       _credentialStore = credentialStore,
       _idFactory = idFactory ?? _newId;

  final AiConnectionProfileStore _profileStore;
  final AiAssistantRepository _assistantRepository;
  final AiCredentialStore _credentialStore;
  final String Function() _idFactory;

  List<AiConnectionProfile> _profiles = const [];
  AiConnectionProfile? _activeProfile;
  bool _isLoading = true;
  Object? _loadError;
  String? _testingProfileId;
  AiConnectionResult? _connectionResult;
  String? _testedProfileId;
  String? _discoveringProfileId;
  List<AiModelInfo> _discoveredModels = const [];
  Object? _modelDiscoveryError;
  bool _disposed = false;

  List<AiConnectionProfile> get profiles => _profiles;
  AiConnectionProfile? get activeProfile => _activeProfile;
  bool get isLoading => _isLoading;
  Object? get loadError => _loadError;
  String? get testingProfileId => _testingProfileId;
  AiConnectionResult? get connectionResult => _connectionResult;
  String? get testedProfileId => _testedProfileId;
  String? get discoveringProfileId => _discoveringProfileId;
  List<AiModelInfo> get discoveredModels => _discoveredModels;
  Object? get modelDiscoveryError => _modelDiscoveryError;
  bool get credentialStorageAvailable => _credentialStore.isAvailable;

  String createProfileId() => _idFactory();

  Future<void> initialize() async {
    _isLoading = true;
    _loadError = null;
    _notifyListeners();
    try {
      await _reload();
    } catch (error) {
      _loadError = error;
    } finally {
      _isLoading = false;
      _notifyListeners();
    }
  }

  Future<void> saveProfile(
    AiConnectionProfile profile, {
    String? bearerToken,
  }) async {
    final shouldActivate = _profiles.isEmpty;
    final existing = _profileWithId(profile.id);
    final oldReference =
        existing?.credentialReference ?? profile.credentialReference;
    final normalizedToken = bearerToken?.trim();
    String? newReference;
    late final AiConnectionProfile profileToSave;

    if (profile.authenticationMode == AiAuthenticationMode.bearerToken) {
      if (!_credentialStore.isAvailable) {
        throw const AiCredentialStoreException(
          'Secure endpoint credentials are not available on this platform.',
        );
      }
      if (normalizedToken?.isNotEmpty ?? false) {
        newReference = await _credentialStore.saveCredential(normalizedToken!);
        profileToSave = profile.copyWith(credentialReference: newReference);
      } else if (oldReference != null) {
        profileToSave = profile.copyWith(credentialReference: oldReference);
      } else {
        throw const AiCredentialStoreException(
          'Enter a bearer token for this connection.',
        );
      }
    } else if (profile.authenticationMode.requiresCredential) {
      throw const AiCredentialStoreException(
        'This authentication method is not available yet.',
      );
    } else {
      if (oldReference != null) {
        await _credentialStore.deleteCredential(oldReference);
      }
      profileToSave = profile.copyWith(clearCredentialReference: true);
    }

    if (!profileToSave.isValid) {
      if (newReference != null) {
        await _deleteCredentialBestEffort(newReference);
      }
      throw const FormatException('The AI connection profile is incomplete.');
    }

    try {
      await _profileStore.saveProfile(profileToSave);
    } catch (_) {
      if (newReference != null) {
        await _deleteCredentialBestEffort(newReference);
      }
      rethrow;
    }
    if (newReference != null &&
        oldReference != null &&
        oldReference != newReference) {
      await _credentialStore.deleteCredential(oldReference);
    }
    if (shouldActivate) {
      await _profileStore.setActiveProfileId(profileToSave.id);
    }
    _clearResultsFor(profileToSave.id);
    await _reloadAndNotify();
  }

  Future<AiConnectionProfile> duplicateProfile(
    AiConnectionProfile profile,
  ) async {
    final duplicate = profile.copyWith(
      id: _idFactory(),
      name: '${profile.name} copy',
      clearCredentialReference: true,
    );
    await _profileStore.saveProfile(duplicate);
    await _reloadAndNotify();
    return duplicate;
  }

  Future<void> deleteProfile(String profileId) async {
    final profile = _profileWithId(profileId);
    if (profile?.credentialReference case final reference?) {
      await _credentialStore.deleteCredential(reference);
    }
    await _profileStore.deleteProfile(profileId);
    _clearResultsFor(profileId);
    await _reloadAndNotify();
  }

  Future<void> selectProfile(String profileId) async {
    await _profileStore.setActiveProfileId(profileId);
    await _reloadAndNotify();
  }

  Future<AiConnectionResult> testConnection(AiConnectionProfile profile) async {
    if (!profile.isValid) {
      const result = AiConnectionResult(
        status: AiConnectionStatus.invalidConfiguration,
        message: 'Complete the connection profile before testing it.',
      );
      _testedProfileId = profile.id;
      _connectionResult = result;
      _notifyListeners();
      return result;
    }

    _testingProfileId = profile.id;
    _testedProfileId = profile.id;
    _connectionResult = null;
    _notifyListeners();
    try {
      final result = await _assistantRepository.testConnection(profile);
      _connectionResult = result;
      return result;
    } catch (error) {
      final result = AiConnectionResult(
        status: AiConnectionStatus.failed,
        message: error.toString(),
      );
      _connectionResult = result;
      return result;
    } finally {
      _testingProfileId = null;
      _notifyListeners();
    }
  }

  Future<List<AiModelInfo>> discoverModels(AiConnectionProfile profile) async {
    _discoveringProfileId = profile.id;
    _discoveredModels = const [];
    _modelDiscoveryError = null;
    _notifyListeners();
    try {
      final models = await _assistantRepository.listModels(profile);
      _discoveredModels = List.unmodifiable(models);
      return _discoveredModels;
    } catch (error) {
      _modelDiscoveryError = error;
      return const [];
    } finally {
      _discoveringProfileId = null;
      _notifyListeners();
    }
  }

  Future<void> _reloadAndNotify() async {
    await _reload();
    _notifyListeners();
  }

  Future<void> _reload() async {
    _profiles = await _profileStore.getProfiles();
    _activeProfile = await _profileStore.getActiveProfile();
  }

  AiConnectionProfile? _profileWithId(String profileId) {
    for (final profile in _profiles) {
      if (profile.id == profileId) return profile;
    }
    return null;
  }

  Future<void> _deleteCredentialBestEffort(String reference) async {
    try {
      await _credentialStore.deleteCredential(reference);
    } catch (_) {}
  }

  void _clearResultsFor(String profileId) {
    if (_testedProfileId == profileId) {
      _testedProfileId = null;
      _connectionResult = null;
    }
    if (_discoveringProfileId == profileId) {
      _discoveringProfileId = null;
      _discoveredModels = const [];
      _modelDiscoveryError = null;
    }
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static String _newId() => const Uuid().v4();
}
