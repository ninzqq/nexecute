import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:nexecute/ai/domain/ai_web_search.dart';
import 'package:nexecute/ai/infrastructure/ai_web_search_connection_profile_codec.dart';
import 'package:nexecute/ai/repositories/ai_web_search_connection_profile_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesAiWebSearchConnectionProfileStore
    implements AiWebSearchConnectionProfileStore {
  static const _profilesKey = 'ai_web_search_connection_profiles_v1';
  static const _activeProfileIdKey =
      'ai_active_web_search_connection_profile_id_v1';

  final LinkedHashMap<String, AiWebSearchConnectionProfile> _profiles =
      LinkedHashMap();
  final _profilesController =
      StreamController<List<AiWebSearchConnectionProfile>>.broadcast();
  final _activeProfileController =
      StreamController<AiWebSearchConnectionProfile?>.broadcast();
  Future<void>? _loadFuture;
  String? _activeProfileId;
  bool _disposed = false;

  @override
  Stream<List<AiWebSearchConnectionProfile>> watchProfiles() async* {
    yield await getProfiles();
    yield* _profilesController.stream;
  }

  @override
  Stream<AiWebSearchConnectionProfile?> watchActiveProfile() async* {
    yield await getActiveProfile();
    yield* _activeProfileController.stream;
  }

  @override
  Future<List<AiWebSearchConnectionProfile>> getProfiles() async {
    await _ensureLoaded();
    return List.unmodifiable(_profiles.values);
  }

  @override
  Future<AiWebSearchConnectionProfile?> getActiveProfile() async {
    await _ensureLoaded();
    final id = _activeProfileId;
    return id == null ? null : _profiles[id];
  }

  @override
  Future<void> saveProfile(AiWebSearchConnectionProfile profile) async {
    await _ensureLoaded();
    _profiles[profile.id] = profile;
    await _persistProfiles();
    _emitProfiles();
    if (profile.id == _activeProfileId) _emitActiveProfile(profile);
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
      throw StateError('Web-search connection profile not found: $profileId');
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
        throw const FormatException(
          'Invalid saved web-search connection profiles.',
        );
      }
      for (final value in decoded) {
        if (value is! Map) {
          throw const FormatException(
            'Invalid saved web-search connection profile.',
          );
        }
        final profile = AiWebSearchConnectionProfileCodec.fromMap(
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
    await preferences.setString(
      _profilesKey,
      jsonEncode(
        _profiles.values
            .map(AiWebSearchConnectionProfileCodec.toMap)
            .toList(growable: false),
      ),
    );
  }

  void _emitProfiles() {
    if (!_disposed) {
      _profilesController.add(List.unmodifiable(_profiles.values));
    }
  }

  void _emitActiveProfile(AiWebSearchConnectionProfile? profile) {
    if (!_disposed) _activeProfileController.add(profile);
  }

  @override
  void dispose() {
    _disposed = true;
    _profilesController.close();
    _activeProfileController.close();
  }
}
