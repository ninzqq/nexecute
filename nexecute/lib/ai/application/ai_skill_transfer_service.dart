import 'package:nexecute/ai/domain/ai_skill.dart';
import 'package:nexecute/ai/infrastructure/ai_skill_markdown_codec.dart';
import 'package:nexecute/ai/repositories/ai_skill_store.dart';

final class AiSkillExport {
  AiSkillExport({required this.fileName, required List<int> bytes})
    : bytes = List.unmodifiable(bytes);

  final String fileName;
  final List<int> bytes;
}

class AiSkillTransferService {
  AiSkillTransferService({
    required AiSkillStore store,
    DateTime Function()? clock,
  }) : _store = store,
       _clock = clock ?? DateTime.now;

  final AiSkillStore _store;
  final DateTime Function() _clock;

  Future<AiSkill> importSkill(
    List<int> bytes, {
    required String sourceFileName,
    String? bodyOnlyId,
    String? bodyOnlyName,
    String? bodyOnlyDescription,
    bool isEnabled = true,
    AiSkillSaveMode saveMode = AiSkillSaveMode.createOnly,
    String? expectedContentHash,
  }) async {
    final skill = AiSkillMarkdownCodec.decode(
      bytes,
      sourceFileName: sourceFileName,
      importedAt: _clock(),
      bodyOnlyId: bodyOnlyId,
      bodyOnlyName: bodyOnlyName,
      bodyOnlyDescription: bodyOnlyDescription,
      isEnabled: isEnabled,
    );
    await _store.saveSkill(
      skill,
      mode: saveMode,
      expectedContentHash: expectedContentHash,
    );
    return skill;
  }

  Future<AiSkillExport> exportSkill(String skillId) async {
    final skill = await _store.getSkill(skillId);
    if (skill == null) {
      throw AiSkillStoreException(
        AiSkillStoreErrorCode.notFound,
        'Skill not found: $skillId.',
      );
    }
    return AiSkillExport(
      fileName: AiSkillDocumentContract.fileName,
      bytes: AiSkillMarkdownCodec.encode(skill),
    );
  }
}
