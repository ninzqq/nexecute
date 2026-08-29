import 'package:nexecute/ai/domain/ai_connection_profile.dart';

abstract interface class AiConnectionProfileStore {
  Stream<List<AiConnectionProfile>> watchProfiles();

  Stream<AiConnectionProfile?> watchActiveProfile();

  Future<List<AiConnectionProfile>> getProfiles();

  Future<AiConnectionProfile?> getActiveProfile();

  Future<void> saveProfile(AiConnectionProfile profile);

  Future<void> deleteProfile(String profileId);

  Future<void> setActiveProfileId(String? profileId);

  void dispose();
}
