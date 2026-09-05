import 'package:nexecute/ai/domain/ai_skill_invocation.dart';

/// Local interface preferences for skill activation.
///
/// Only IDs and content hashes are persisted. Skill instruction bodies remain
/// exclusively in [AiSkillStore].
abstract interface class AiSkillPreferencesStore {
  Stream<List<AiSkillReference>> watchDefaultSkills();

  Future<List<AiSkillReference>> getDefaultSkills();

  Future<void> setDefaultSkills(Iterable<AiSkillReference> references);

  void dispose();
}
