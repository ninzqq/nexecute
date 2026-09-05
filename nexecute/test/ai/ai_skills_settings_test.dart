import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('distinguishes unavailable storage from an empty catalog', (
    tester,
  ) async {
    const store = UnavailableAiSkillStore();
    final preferences = InMemoryAiSkillPreferencesStore();
    addTearDown(preferences.dispose);

    await tester.pumpWidget(_app(store, preferences, _FakeSkillFileGateway()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-skills-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('ai-skills-empty')), findsNothing);
    expect(
      find.textContaining('Ordinary AI chat remains available'),
      findsOneWidget,
    );
  });

  testWidgets('creates, edits, duplicates, defaults, disables, and deletes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = InMemoryAiSkillStore();
    final preferences = InMemoryAiSkillPreferencesStore();
    final gateway = _FakeSkillFileGateway();
    addTearDown(store.dispose);
    addTearDown(preferences.dispose);
    await tester.pumpWidget(_app(store, preferences, gateway));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-skills-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-skill-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ai-skill-id-field')),
      'suomen-kieli',
    );
    await tester.enterText(
      find.byKey(const Key('ai-skill-name-field')),
      'Suomen kieli',
    );
    await tester.enterText(
      find.byKey(const Key('ai-skill-description-field')),
      'Kirjoittamisen ohje',
    );
    await tester.enterText(
      find.byKey(const Key('ai-skill-instructions-field')),
      'Kirjoita huolellista suomea.',
    );
    await tester.tap(find.byKey(const Key('ai-skill-save')));
    await tester.pumpAndSettle();

    expect(find.text('Suomen kieli'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-skill-default-suomen-kieli')));
    await tester.pumpAndSettle();
    expect((await preferences.getDefaultSkills()).single.id, 'suomen-kieli');
    expect(find.textContaining('active by default'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai-skill-enabled-suomen-kieli')));
    await tester.pumpAndSettle();
    expect((await preferences.getDefaultSkills()), isEmpty);
    expect(find.textContaining('disabled'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-skill-enabled-suomen-kieli')));
    await tester.pumpAndSettle();

    await _chooseAction(tester, 'suomen-kieli', 'Edit');
    await tester.enterText(
      find.byKey(const Key('ai-skill-instructions-field')),
      'Muokattu ohje.',
    );
    await tester.tap(find.byKey(const Key('ai-skill-save')));
    await tester.pumpAndSettle();
    expect(
      (await store.getSkill('suomen-kieli'))?.instructions,
      'Muokattu ohje.',
    );

    await _chooseAction(tester, 'suomen-kieli', 'Duplicate');
    await tester.tap(find.byKey(const Key('ai-skill-save')));
    await tester.pumpAndSettle();
    expect(await store.getSkills(), hasLength(2));
    expect(find.byKey(const Key('ai-skill-suomen-kieli-copy')), findsOneWidget);

    await _chooseAction(tester, 'suomen-kieli-copy', 'Delete');
    await tester.tap(find.byKey(const Key('ai-skill-confirm-delete')));
    await tester.pumpAndSettle();
    expect(await store.getSkills(), hasLength(1));
  });

  testWidgets('imports body-only Markdown unchanged and exports SKILL.md', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const body = 'Tunnista toimintatila.\n\nÄlä muuta tätä runkoa.';
    final store = InMemoryAiSkillStore();
    final preferences = InMemoryAiSkillPreferencesStore();
    final gateway = _FakeSkillFileGateway(
      picked: [
        AiPickedSkillDocument(fileName: 'SKILL.md', bytes: utf8.encode(body)),
      ],
    );
    addTearDown(store.dispose);
    addTearDown(preferences.dispose);
    await tester.pumpWidget(_app(store, preferences, gateway));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ai-skill-import')));
    await tester.pumpAndSettle();
    expect(
      find.text('The Markdown instruction body will be imported unchanged.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('ai-skill-import-id')),
      'suomen-kieli',
    );
    await tester.enterText(
      find.byKey(const Key('ai-skill-import-name')),
      'Suomen kieli',
    );
    await tester.enterText(
      find.byKey(const Key('ai-skill-import-description')),
      'Suomenkielinen kirjoittaminen',
    );
    await tester.tap(find.byKey(const Key('ai-skill-import-metadata-save')));
    await tester.pumpAndSettle();

    final imported = await store.getSkill('suomen-kieli');
    expect(imported?.instructions, body);
    expect(await preferences.getDefaultSkills(), isEmpty);
    expect(find.textContaining('not active automatically'), findsOneWidget);

    await _chooseAction(tester, 'suomen-kieli', 'Export SKILL.md');
    await tester.pumpAndSettle();
    expect(gateway.exports, hasLength(1));
    expect(gateway.exports.single.fileName, 'SKILL.md');
    expect(utf8.decode(gateway.exports.single.bytes), contains(body));
  });

  testWidgets('requires confirmation before replacing a duplicate import', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = _skill('Original instructions');
    final replacement = _skill('Replacement instructions');
    final store = InMemoryAiSkillStore(skills: [original]);
    final preferences = InMemoryAiSkillPreferencesStore(
      defaultSkills: [AiSkillReference.fromSkill(original)],
    );
    final gateway = _FakeSkillFileGateway(
      picked: [
        AiPickedSkillDocument(
          fileName: 'SKILL.md',
          bytes: AiSkillMarkdownCodec.encode(replacement),
        ),
      ],
    );
    addTearDown(store.dispose);
    addTearDown(preferences.dispose);
    await tester.pumpWidget(_app(store, preferences, gateway));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ai-skill-import')));
    await tester.pumpAndSettle();
    expect(find.text('Replace existing skill?'), findsOneWidget);
    expect(
      (await store.getSkill(original.id))?.instructions,
      original.instructions,
    );
    await tester.tap(find.byKey(const Key('ai-skill-confirm-replace')));
    await tester.pumpAndSettle();

    final failureMessages =
        tester
            .widgetList<Text>(find.byType(Text))
            .map((widget) => widget.data)
            .whereType<String>()
            .where((text) => text.contains('Skill action failed'))
            .toList();
    expect(failureMessages, isEmpty);

    final saved = await store.getSkill(original.id);
    expect(saved?.instructions, replacement.instructions);
    expect(
      (await preferences.getDefaultSkills()).single.contentHash,
      saved?.contentHash,
    );
  });
}

Future<void> _chooseAction(
  WidgetTester tester,
  String skillId,
  String label,
) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(Key('ai-skill-$skillId')),
      matching: find.byTooltip('Skill actions'),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Widget _app(
  AiSkillStore store,
  AiSkillPreferencesStore preferences,
  AiSkillFileGateway gateway,
) => MultiProvider(
  providers: [
    Provider<AiSkillStore>.value(value: store),
    Provider<AiSkillPreferencesStore>.value(value: preferences),
    Provider<AiSkillTransferService>(
      create: (_) => AiSkillTransferService(store: store),
    ),
    Provider<AiSkillFileGateway>.value(value: gateway),
  ],
  child: const MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: AiSkillsSettings(),
      ),
    ),
  ),
);

AiSkill _skill(String instructions) => AiSkill(
  id: 'suomen-kieli',
  name: 'Suomen kieli',
  description: 'Finnish writing',
  instructions: instructions,
  createdAt: DateTime.utc(2026, 9, 5),
  updatedAt: DateTime.utc(2026, 9, 5),
);

final class _ExportedDocument {
  _ExportedDocument({required this.fileName, required List<int> bytes})
    : bytes = List.unmodifiable(bytes);

  final String fileName;
  final List<int> bytes;
}

final class _FakeSkillFileGateway implements AiSkillFileGateway {
  _FakeSkillFileGateway({List<AiPickedSkillDocument> picked = const []})
    : picked = List.of(picked);

  final List<AiPickedSkillDocument> picked;
  final List<_ExportedDocument> exports = [];

  @override
  Future<AiPickedSkillDocument?> pickSkillDocument() async =>
      picked.isEmpty ? null : picked.removeAt(0);

  @override
  Future<bool> exportSkillDocument({
    required String fileName,
    required List<int> bytes,
  }) async {
    exports.add(_ExportedDocument(fileName: fileName, bytes: bytes));
    return true;
  }
}
