import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  final importedAt = DateTime.utc(2026, 9, 5, 14);

  test('imports body-only Markdown and exports a complete SKILL.md', () async {
    final store = InMemoryAiSkillStore();
    addTearDown(store.dispose);
    final service = AiSkillTransferService(
      store: store,
      clock: () => importedAt,
    );

    final imported = await service.importSkill(
      utf8.encode('Vastaa aina suomeksi.'),
      sourceFileName: 'SKILL.md',
      bodyOnlyId: 'suomen-kieli',
      bodyOnlyName: 'Suomen kieli',
      bodyOnlyDescription: 'Suomenkielinen kirjoitusapu.',
    );
    final exported = await service.exportSkill(imported.id);
    final restored = AiSkillMarkdownCodec.decode(
      exported.bytes,
      sourceFileName: exported.fileName,
      importedAt: importedAt,
    );

    expect((await store.getSkills()).single.id, imported.id);
    expect(exported.fileName, 'SKILL.md');
    expect(restored.contentHash, imported.contentHash);
    expect(() => exported.bytes.clear(), throwsUnsupportedError);
  });

  test(
    'preserves duplicate IDs until the caller selects replacement',
    () async {
      final original = AiSkill(
        id: 'suomen-kieli',
        name: 'Suomen kieli',
        description: 'Suomenkielinen kirjoitusapu.',
        instructions: 'Original',
        createdAt: importedAt,
        updatedAt: importedAt,
      );
      final store = InMemoryAiSkillStore(skills: [original]);
      addTearDown(store.dispose);
      final service = AiSkillTransferService(
        store: store,
        clock: () => importedAt.add(const Duration(days: 1)),
      );
      final replacementDocument = AiSkillMarkdownCodec.encode(
        original.copyWith(
          instructions: 'Replacement',
          updatedAt: importedAt.add(const Duration(days: 1)),
        ),
      );

      await expectLater(
        service.importSkill(replacementDocument, sourceFileName: 'SKILL.md'),
        throwsA(
          isA<AiSkillStoreException>().having(
            (error) => error.code,
            'code',
            AiSkillStoreErrorCode.conflict,
          ),
        ),
      );
      expect((await store.getSkill(original.id))?.instructions, 'Original');

      final replaced = await service.importSkill(
        replacementDocument,
        sourceFileName: 'SKILL.md',
        saveMode: AiSkillSaveMode.replaceOnly,
        expectedContentHash: original.contentHash,
      );
      expect(replaced.instructions, 'Replacement');
    },
  );

  test('reports a missing export without creating a document', () async {
    final store = InMemoryAiSkillStore();
    addTearDown(store.dispose);
    final service = AiSkillTransferService(store: store);

    await expectLater(
      service.exportSkill('missing'),
      throwsA(
        isA<AiSkillStoreException>().having(
          (error) => error.code,
          'code',
          AiSkillStoreErrorCode.notFound,
        ),
      ),
    );
  });
}
