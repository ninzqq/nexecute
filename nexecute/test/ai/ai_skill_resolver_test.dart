import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  test('resolves exact enabled revisions in deterministic ID order', () async {
    final alpha = _skill('alpha', 'Alpha instructions');
    final zulu = _skill('zulu', 'Zulu instructions');
    final resolver = AiSkillResolver(
      store: InMemoryAiSkillStore(skills: [zulu, alpha]),
    );

    final result = await resolver.resolve([
      AiSkillReference.fromSkill(zulu),
      AiSkillReference.fromSkill(alpha),
    ]);

    expect(result.map((skill) => skill.id), ['alpha', 'zulu']);
    expect(result.first.instructions, 'Alpha instructions');
    expect(() => result.clear(), throwsUnsupportedError);
  });

  test('reports changed revisions without exposing instructions', () async {
    final previous = _skill('finnish', 'Old instructions');
    final current = _skill('finnish', 'New private instructions');
    final resolver = AiSkillResolver(
      store: InMemoryAiSkillStore(skills: [current]),
    );

    late AiSkillResolutionException failure;
    try {
      await resolver.resolve([AiSkillReference.fromSkill(previous)]);
      fail('Expected resolution to fail.');
    } on AiSkillResolutionException catch (error) {
      failure = error;
    }

    expect(failure.issues.single.kind, AiSkillResolutionIssueKind.changed);
    expect(failure.issues.single.availableContentHash, current.contentHash);
    expect(failure.toString(), isNot(contains(current.instructions)));
  });

  test('distinguishes missing, disabled, and unavailable skills', () async {
    final disabled = _skill('disabled', 'Disabled').copyWith(isEnabled: false);
    final store = InMemoryAiSkillStore(skills: [disabled]);
    final resolver = AiSkillResolver(store: store);
    final missing = AiSkillReference(
      id: 'missing',
      contentHash: List.filled(64, '0').join(),
    );

    await expectLater(
      resolver.resolve([missing, AiSkillReference.fromSkill(disabled)]),
      throwsA(
        isA<AiSkillResolutionException>().having(
          (error) => error.issues.map((issue) => issue.kind).toSet(),
          'issue kinds',
          {
            AiSkillResolutionIssueKind.missing,
            AiSkillResolutionIssueKind.disabled,
          },
        ),
      ),
    );
    await expectLater(
      const AiSkillResolver(
        store: UnavailableAiSkillStore(),
      ).resolve([missing]),
      throwsA(
        isA<AiSkillResolutionException>().having(
          (error) => error.issues.single.kind,
          'issue kind',
          AiSkillResolutionIssueKind.storageUnavailable,
        ),
      ),
    );
  });
}

AiSkill _skill(String id, String instructions) => AiSkill(
  id: id,
  name: id,
  description: 'Test skill',
  instructions: instructions,
  createdAt: DateTime.utc(2026, 9, 5),
  updatedAt: DateTime.utc(2026, 9, 5),
);
