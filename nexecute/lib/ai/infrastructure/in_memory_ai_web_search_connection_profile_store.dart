import 'dart:async';
import 'dart:collection';

import 'package:nexecute/ai/domain/ai_web_search.dart';
import 'package:nexecute/ai/repositories/ai_web_search_connection_profile_store.dart';

class InMemoryAiWebSearchConnectionProfileStore
    implements AiWebSearchConnectionProfileStore {
  InMemoryAiWebSearchConnectionProfileStore({
    Iterable<AiWebSearchConnectionProfile> profiles = const [],
    String? activeProfileId,
  }) : _profiles = LinkedHashMap.fromEntries(
         profiles.map((profile) => MapEntry(profile.id, profile)),
       ),
       _activeProfileId = activeProfileId;

  final LinkedHashMap<String, AiWebSearchConnectionProfile> _profiles;
  final _profilesController =
      StreamController<List<AiWebSearchConnectionProfile>>.broadcast();
  final _activeProfileController =
      StreamController<AiWebSearchConnectionProfile?>.broadcast();
  String? _activeProfileId;

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
  Future<List<AiWebSearchConnectionProfile>> getProfiles() async =>
      List.unmodifiable(_profiles.values);

  @override
  Future<AiWebSearchConnectionProfile?> getActiveProfile() async {
    final id = _activeProfileId;
    return id == null ? null : _profiles[id];
  }

  @override
  Future<void> saveProfile(AiWebSearchConnectionProfile profile) async {
    _profiles[profile.id] = profile;
    _profilesController.add(await getProfiles());
    if (profile.id == _activeProfileId) {
      _activeProfileController.add(profile);
    }
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    if (_profiles.remove(profileId) == null) return;
    _profilesController.add(await getProfiles());
    if (_activeProfileId == profileId) {
      _activeProfileId = null;
      _activeProfileController.add(null);
    }
  }

  @override
  Future<void> setActiveProfileId(String? profileId) async {
    if (profileId != null && !_profiles.containsKey(profileId)) {
      throw StateError('Web-search connection profile not found: $profileId');
    }
    if (_activeProfileId == profileId) return;
    _activeProfileId = profileId;
    _activeProfileController.add(await getActiveProfile());
  }

  @override
  void dispose() {
    _profilesController.close();
    _activeProfileController.close();
  }
}
