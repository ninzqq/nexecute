import 'dart:async';
import 'dart:collection';

import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/ai/repositories/ai_connection_profile_store.dart';

class InMemoryAiConnectionProfileStore implements AiConnectionProfileStore {
  InMemoryAiConnectionProfileStore({
    Iterable<AiConnectionProfile> profiles = const [],
    String? activeProfileId,
  }) : _profiles = LinkedHashMap.fromEntries(
         profiles.map((profile) => MapEntry(profile.id, profile)),
       ),
       _activeProfileId = activeProfileId;

  final LinkedHashMap<String, AiConnectionProfile> _profiles;
  final _profilesController =
      StreamController<List<AiConnectionProfile>>.broadcast();
  final _activeProfileController =
      StreamController<AiConnectionProfile?>.broadcast();
  String? _activeProfileId;

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
  Future<List<AiConnectionProfile>> getProfiles() async =>
      List.unmodifiable(_profiles.values);

  @override
  Future<AiConnectionProfile?> getActiveProfile() async {
    final activeProfileId = _activeProfileId;
    return activeProfileId == null ? null : _profiles[activeProfileId];
  }

  @override
  Future<void> saveProfile(AiConnectionProfile profile) async {
    _profiles[profile.id] = profile;
    _profilesController.add(await getProfiles());
    if (profile.id == _activeProfileId) {
      _activeProfileController.add(profile);
    }
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    final removed = _profiles.remove(profileId);
    if (removed == null) return;

    _profilesController.add(await getProfiles());
    if (_activeProfileId == profileId) {
      _activeProfileId = null;
      _activeProfileController.add(null);
    }
  }

  @override
  Future<void> setActiveProfileId(String? profileId) async {
    if (profileId != null && !_profiles.containsKey(profileId)) {
      throw StateError('AI connection profile not found: $profileId');
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
