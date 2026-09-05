import 'package:nexecute/ai/application/ai_request_budget.dart';
import '../support/fake_ai_dependencies.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  test(
    'budgets multi-skill defaults and preserves the accepted set on failure',
    () async {
      final small = _skill(instructions: 'Be brief');
      final large = small.copyWith(id: 'large', instructions: 'ä' * 11000);
      final store = InMemoryAiSkillStore(skills: [small, large]);
      final preferences = InMemoryAiSkillPreferencesStore();
      final profile = AiConnectionProfile(
        id: 'p',
        name: 'P',
        protocol: AiProtocol.openAiCompatibleChat,
        baseUrl: Uri.parse('http://localhost/v1'),
        modelId: 'm',
        allowMultipleSkills: true,
      );
      final profiles = FakeAiConnectionProfileStore(
        profiles: [profile],
        activeProfileId: 'p',
      );
      final controller = AiSkillsController(
        store: store,
        preferencesStore: preferences,
        profileStore: profiles,
      );
      addTearDown(controller.dispose);
      addTearDown(store.dispose);
      addTearDown(preferences.dispose);
      addTearDown(profiles.dispose);
      await controller.initialize();
      await controller.setDefault(AiSkillMetadata.fromSkill(small), true);
      await expectLater(
        controller.setDefault(AiSkillMetadata.fromSkill(large), true),
        throwsA(isA<AiRequestBudgetException>()),
      );
      expect(await preferences.getDefaultSkills(), [
        AiSkillReference.fromSkill(small),
      ]);
      await profiles.saveProfile(profile.copyWith(contextWindowTokens: 32768));
      await controller.setDefault(AiSkillMetadata.fromSkill(large), true);
      expect((await preferences.getDefaultSkills()).length, 2);
    },
  );

  test('manages enabled state and exact default revisions', () async {
    final original = _skill(instructions: 'Original');
    final store = InMemoryAiSkillStore(skills: [original]);
    final preferences = InMemoryAiSkillPreferencesStore();
    final controller = AiSkillsController(
      store: store,
      preferencesStore: preferences,
      clock: () => DateTime.utc(2026, 9, 6),
    );
    addTearDown(controller.dispose);
    addTearDown(store.dispose);
    addTearDown(preferences.dispose);
    await controller.initialize();

    await controller.setDefault(controller.skills.single, true);
    expect(controller.defaultSkills, [AiSkillReference.fromSkill(original)]);

    final updated = original.copyWith(
      instructions: 'Updated',
      updatedAt: DateTime.utc(2026, 9, 6),
    );
    await controller.updateSkill(
      updated,
      expectedContentHash: original.contentHash,
    );
    expect(
      (await preferences.getDefaultSkills()).single.contentHash,
      updated.contentHash,
    );

    await controller.setEnabled(AiSkillMetadata.fromSkill(updated), false);
    expect(await preferences.getDefaultSkills(), isEmpty);
    expect((await store.getSkill(updated.id))?.isEnabled, isFalse);
  });

  test('surfaces optimistic edit conflicts', () async {
    final original = _skill(instructions: 'Original');
    final external = original.copyWith(
      instructions: 'External edit',
      updatedAt: DateTime.utc(2026, 9, 6),
    );
    final store = InMemoryAiSkillStore(skills: [external]);
    final controller = AiSkillsController(store: store);
    addTearDown(controller.dispose);
    addTearDown(store.dispose);

    await expectLater(
      controller.updateSkill(
        original.copyWith(
          instructions: 'My edit',
          updatedAt: DateTime.utc(2026, 9, 7),
        ),
        expectedContentHash: original.contentHash,
      ),
      throwsA(
        isA<AiSkillStoreException>().having(
          (error) => error.code,
          'code',
          AiSkillStoreErrorCode.conflict,
        ),
      ),
    );
  });
}

AiSkill _skill({required String instructions}) => AiSkill(
  id: 'suomen-kieli',
  name: 'Suomen kieli',
  description: 'Finnish writing',
  instructions: instructions,
  createdAt: DateTime.utc(2026, 9, 5),
  updatedAt: DateTime.utc(2026, 9, 5),
);
