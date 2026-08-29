import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/ai/infrastructure/ai_connection_profile_codec.dart';
import 'package:nexecute/ai/repositories/ai_connection_profile_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesAiConnectionProfileStore
    implements AiConnectionProfileStore {
  SharedPreferencesAiConnectionProfileStore();

  static const _profilesKey = 'ai_connection_profiles_v1';
  static const _activeProfileIdKey = 'ai_active_connection_profile_id_v1';

  final LinkedHashMap<String, AiConnectionProfile> _profiles = LinkedHashMap();
  final _profilesController =
      StreamController<List<AiConnectionProfile>>.broadcast();
  final _activeProfileController =
      StreamController<AiConnectionProfile?>.broadcast();
  Future<void>? _loadFuture;
  String? _activeProfileId;
  bool _disposed = false;

  @override
  Stream<List<AiConnectionProfile>> watchProfiles() async* {
    yield await getProfiles();
    yield* _profilesController.stream;
  }

  @override
  Stream<AiConnectionProfile?> watchActiveProfile() async* {
    yield await getActiveProfile();
    yield* _activeProfileController.stream;
  }

  @override
  Future<List<AiConnectionProfile>> getProfiles() async {
    await _ensureLoaded();
    return List.unmodifiable(_profiles.values);
  }

  @override
  Future<AiConnectionProfile?> getActiveProfile() async {
    await _ensureLoaded();
    final activeProfileId = _activeProfileId;
    return activeProfileId == null ? null : _profiles[activeProfileId];
  }

  @override
  Future<void> saveProfile(AiConnectionProfile profile) async {
    await _ensureLoaded();
    _profiles[profile.id] = profile;
    await _persistProfiles();
    _emitProfiles();
    if (profile.id == _activeProfileId) {
      _emitActiveProfile(profile);
    }
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    await _ensureLoaded();
    if (_profiles.remove(profileId) == null) return;

    await _persistProfiles();
    _emitProfiles();
    if (_activeProfileId == profileId) {
      _activeProfileId = null;
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_activeProfileIdKey);
      _emitActiveProfile(null);
    }
  }

  @override
  Future<void> setActiveProfileId(String? profileId) async {
    await _ensureLoaded();
    if (profileId != null && !_profiles.containsKey(profileId)) {
      throw StateError('AI connection profile not found: $profileId');
    }
    if (_activeProfileId == profileId) return;

    _activeProfileId = profileId;
    final preferences = await SharedPreferences.getInstance();
    if (profileId == null) {
      await preferences.remove(_activeProfileIdKey);
    } else {
      await preferences.setString(_activeProfileIdKey, profileId);
    }
    _emitActiveProfile(profileId == null ? null : _profiles[profileId]);
  }

  Future<void> _ensureLoaded() => _loadFuture ??= _load();

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final encodedProfiles = preferences.getString(_profilesKey);
    if (encodedProfiles != null) {
      final decoded = jsonDecode(encodedProfiles);
      if (decoded is! List) {
        throw const FormatException('Invalid saved AI connection profiles');
      }
      for (final value in decoded) {
        if (value is! Map) {
          throw const FormatException('Invalid saved AI connection profile');
        }
        final profile = AiConnectionProfileCodec.fromMap(
          Map<String, Object?>.from(value),
        );
        _profiles[profile.id] = profile;
      }
    }

    final savedActiveId = preferences.getString(_activeProfileIdKey);
    _activeProfileId =
        savedActiveId != null && _profiles.containsKey(savedActiveId)
            ? savedActiveId
            : null;
  }

  Future<void> _persistProfiles() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _profiles.values.map(AiConnectionProfileCodec.toMap).toList(),
    );
    await preferences.setString(_profilesKey, encoded);
  }

  void _emitProfiles() {
    if (_disposed) return;
    _profilesController.add(List.unmodifiable(_profiles.values));
  }

  void _emitActiveProfile(AiConnectionProfile? profile) {
    if (_disposed) return;
    _activeProfileController.add(profile);
  }

  @override
  void dispose() {
    _disposed = true;
    _profilesController.close();
    _activeProfileController.close();
  }
}
