import 'dart:async';
import 'dart:convert';

import 'package:nexecute/ai/domain/ai_skill_invocation.dart';
import 'package:nexecute/ai/repositories/ai_skill_preferences_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class SharedPreferencesAiSkillPreferencesStore
    implements AiSkillPreferencesStore {
  static const _key = 'ai.skillPreferences.defaultSkills.v1';

  final _controller = StreamController<List<AiSkillReference>>.broadcast();

  @override
  Future<List<AiSkillReference>> getDefaultSkills() async {
    final preferences = await SharedPreferences.getInstance();
    final source = preferences.getString(_key);
    if (source == null) return const [];
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) return const [];
      final references = <AiSkillReference>[];
      for (final value in decoded) {
        if (value is! Map ||
            value.keys.any((key) => key != 'id' && key != 'contentHash')) {
          return const [];
        }
        final id = value['id'];
        final contentHash = value['contentHash'];
        if (id is! String || contentHash is! String) return const [];
        references.add(AiSkillReference(id: id, contentHash: contentHash));
      }
      return normalizeAiSkillReferences(references);
    } on FormatException {
      return const [];
    } on ArgumentError {
      return const [];
    }
  }

  @override
  Stream<List<AiSkillReference>> watchDefaultSkills() async* {
    yield await getDefaultSkills();
    yield* _controller.stream;
  }

  @override
  Future<void> setDefaultSkills(Iterable<AiSkillReference> references) async {
    final normalized = normalizeAiSkillReferences(references);
    final encoded = jsonEncode([
      for (final reference in normalized)
        {'id': reference.id, 'contentHash': reference.contentHash},
    ]);
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(_key, encoded)) {
      throw StateError('Default skill preferences could not be saved.');
    }
    _controller.add(normalized);
  }

  @override
  void dispose() => _controller.close();
}
