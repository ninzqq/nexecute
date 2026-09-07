import 'package:nexecute/ai/domain/ai_web_search.dart';

abstract interface class AiWebSearchConnectionProfileStore {
  Stream<List<AiWebSearchConnectionProfile>> watchProfiles();

  Stream<AiWebSearchConnectionProfile?> watchActiveProfile();

  Future<List<AiWebSearchConnectionProfile>> getProfiles();

  Future<AiWebSearchConnectionProfile?> getActiveProfile();

  Future<void> saveProfile(AiWebSearchConnectionProfile profile);

  Future<void> deleteProfile(String profileId);

  Future<void> setActiveProfileId(String? profileId);

  void dispose();
}
