import 'dart:async';
import 'dart:collection';

import 'package:nexecute/ai/domain/ai_skill.dart';
import 'package:nexecute/ai/repositories/ai_skill_store.dart';

class InMemoryAiSkillStore implements AiSkillStore {
  InMemoryAiSkillStore({Iterable<AiSkill> skills = const []})
    : _skills = LinkedHashMap.fromEntries(
        skills.map((skill) => MapEntry(skill.id, skill)),
      );

  final LinkedHashMap<String, AiSkill> _skills;
  final _skillsController = StreamController<List<AiSkillMetadata>>.broadcast();

  @override
  bool get isAvailable => true;

  @override
  Stream<List<AiSkillMetadata>> watchSkills() async* {
    yield await getSkills();
    yield* _skillsController.stream;
  }

  @override
  Future<List<AiSkillMetadata>> getSkills() async => _metadata();

  @override
  Future<List<AiSkillMetadata>> searchSkills(String query) async =>
      _filterMetadata(_metadata(), query);

  @override
  Future<AiSkill?> getSkill(String skillId) async => _skills[skillId];

  @override
  Future<void> saveSkill(
    AiSkill skill, {
    AiSkillSaveMode mode = AiSkillSaveMode.upsert,
    String? expectedContentHash,
  }) async {
    final existing = _skills[skill.id];
    _validateSave(
      skill.id,
      existing: existing,
      mode: mode,
      expectedContentHash: expectedContentHash,
    );
    _skills[skill.id] = skill;
    _skillsController.add(_metadata());
  }

  @override
  Future<void> deleteSkill(
    String skillId, {
    String? expectedContentHash,
  }) async {
    final existing = _skills[skillId];
    if (existing == null) return;
    if (expectedContentHash != null &&
        existing.contentHash != expectedContentHash) {
      throw const AiSkillStoreException(
        AiSkillStoreErrorCode.conflict,
        'The skill changed before it could be deleted.',
      );
    }
    _skills.remove(skillId);
    _skillsController.add(_metadata());
  }

  List<AiSkillMetadata> _metadata() {
    final values =
        _skills.values.map(AiSkillMetadata.fromSkill).toList()
          ..sort(_compareMetadata);
    return List.unmodifiable(values);
  }

  @override
  void dispose() {
    _skillsController.close();
  }
}

void _validateSave(
  String skillId, {
  required AiSkill? existing,
  required AiSkillSaveMode mode,
  required String? expectedContentHash,
}) {
  if (existing == null && mode == AiSkillSaveMode.replaceOnly) {
    throw AiSkillStoreException(
      AiSkillStoreErrorCode.notFound,
      'Skill not found: $skillId.',
    );
  }
  if (existing != null && mode == AiSkillSaveMode.createOnly) {
    throw AiSkillStoreException(
      AiSkillStoreErrorCode.conflict,
      'A skill with id $skillId already exists.',
    );
  }
  if (expectedContentHash != null &&
      existing?.contentHash != expectedContentHash) {
    throw const AiSkillStoreException(
      AiSkillStoreErrorCode.conflict,
      'The skill changed before it could be saved.',
    );
  }
}

int _compareMetadata(AiSkillMetadata left, AiSkillMetadata right) {
  final byName = left.name.toLowerCase().compareTo(right.name.toLowerCase());
  return byName != 0 ? byName : left.id.compareTo(right.id);
}

List<AiSkillMetadata> _filterMetadata(
  List<AiSkillMetadata> values,
  String query,
) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return values;
  return List.unmodifiable(
    values.where(
      (skill) =>
          skill.id.toLowerCase().contains(normalized) ||
          skill.name.toLowerCase().contains(normalized) ||
          skill.description.toLowerCase().contains(normalized),
    ),
  );
}
