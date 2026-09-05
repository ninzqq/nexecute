import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('shared preferences persists only normalized IDs and hashes', () async {
    final alpha = _reference('alpha', 'a');
    final zulu = _reference('zulu', 'f');
    final store = SharedPreferencesAiSkillPreferencesStore();
    addTearDown(store.dispose);

    await store.setDefaultSkills([zulu, alpha]);

    final restored = SharedPreferencesAiSkillPreferencesStore();
    addTearDown(restored.dispose);
    expect(await restored.getDefaultSkills(), [alpha, zulu]);
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(
      'ai.skillPreferences.defaultSkills.v1',
    );
    expect(encoded, contains('"id":"alpha"'));
    expect(encoded, isNot(contains('instructions')));
  });

  test('malformed preference data fails closed to no defaults', () async {
    SharedPreferences.setMockInitialValues({
      'ai.skillPreferences.defaultSkills.v1':
          '[{"id":"../escape","contentHash":"secret"}]',
    });
    final store = SharedPreferencesAiSkillPreferencesStore();
    addTearDown(store.dispose);

    expect(await store.getDefaultSkills(), isEmpty);
  });
}

AiSkillReference _reference(String id, String hashCharacter) =>
    AiSkillReference(
      id: id,
      contentHash: List.filled(64, hashCharacter).join(),
    );
