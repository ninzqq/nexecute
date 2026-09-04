import 'package:nexecute/ai/domain/ai_skill.dart';

enum AiSkillSaveMode { createOnly, replaceOnly, upsert }

enum AiSkillStoreErrorCode {
  unavailable,
  notFound,
  conflict,
  corruptData,
  ioFailure,
}

final class AiSkillStoreException implements Exception {
  const AiSkillStoreException(this.code, this.message, {this.cause});

  final AiSkillStoreErrorCode code;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

abstract interface class AiSkillStore {
  bool get isAvailable;

  Stream<List<AiSkillMetadata>> watchSkills();

  Future<List<AiSkillMetadata>> getSkills();

  Future<List<AiSkillMetadata>> searchSkills(String query);

  Future<AiSkill?> getSkill(String skillId);

  Future<void> saveSkill(
    AiSkill skill, {
    AiSkillSaveMode mode = AiSkillSaveMode.upsert,
    String? expectedContentHash,
  });

  Future<void> deleteSkill(String skillId, {String? expectedContentHash});

  void dispose();
}
