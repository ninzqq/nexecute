import 'dart:async';

import 'package:nexecute/ai/domain/ai_skill_invocation.dart';
import 'package:nexecute/ai/repositories/ai_skill_preferences_store.dart';

final class InMemoryAiSkillPreferencesStore implements AiSkillPreferencesStore {
  InMemoryAiSkillPreferencesStore({
    Iterable<AiSkillReference> defaultSkills = const [],
  }) : _defaultSkills = normalizeAiSkillReferences(defaultSkills);

  List<AiSkillReference> _defaultSkills;
  final _controller = StreamController<List<AiSkillReference>>.broadcast();

  @override
  Future<List<AiSkillReference>> getDefaultSkills() async => _defaultSkills;

  @override
  Stream<List<AiSkillReference>> watchDefaultSkills() async* {
    yield _defaultSkills;
    yield* _controller.stream;
  }

  @override
  Future<void> setDefaultSkills(Iterable<AiSkillReference> references) async {
    _defaultSkills = normalizeAiSkillReferences(references);
    _controller.add(_defaultSkills);
  }

  @override
  void dispose() => _controller.close();
}
