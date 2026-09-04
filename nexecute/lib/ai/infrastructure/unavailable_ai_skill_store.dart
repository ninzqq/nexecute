import 'package:nexecute/ai/domain/ai_skill.dart';
import 'package:nexecute/ai/repositories/ai_skill_store.dart';

class UnavailableAiSkillStore implements AiSkillStore {
  const UnavailableAiSkillStore();

  @override
  bool get isAvailable => false;

  @override
  Stream<List<AiSkillMetadata>> watchSkills() async* {
    throw _unavailable;
  }

  @override
  Future<List<AiSkillMetadata>> getSkills() => Future.error(_unavailable);

  @override
  Future<List<AiSkillMetadata>> searchSkills(String query) =>
      Future.error(_unavailable);

  @override
  Future<AiSkill?> getSkill(String skillId) => Future.error(_unavailable);

  @override
  Future<void> saveSkill(
    AiSkill skill, {
    AiSkillSaveMode mode = AiSkillSaveMode.upsert,
    String? expectedContentHash,
  }) => Future.error(_unavailable);

  @override
  Future<void> deleteSkill(String skillId, {String? expectedContentHash}) =>
      Future.error(_unavailable);

  @override
  void dispose() {}

  static const _unavailable = AiSkillStoreException(
    AiSkillStoreErrorCode.unavailable,
    'AI skill storage is not available on this platform.',
  );
}
