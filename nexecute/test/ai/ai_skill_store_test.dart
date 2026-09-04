import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/ai/infrastructure/file_system_ai_skill_store.dart';
import 'package:path/path.dart' as path;

void main() {
  group('in-memory skill store', () {
    _skillStoreContract(InMemoryAiSkillStore.new);
  });

  group('filesystem skill store', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('nexecute-skills-');
    });

    tearDown(() async {
      final type = await FileSystemEntity.type(
        directory.path,
        followLinks: false,
      );
      if (type == FileSystemEntityType.link) {
        await Link(directory.path).delete();
      } else if (type == FileSystemEntityType.directory) {
        await directory.delete(recursive: true);
      }
    });

    AiSkillStore createStore() =>
        FileSystemAiSkillStore(directoryProvider: () async => directory);

    _skillStoreContract(createStore);

    test(
      'persists searchable metadata separately from immutable bodies',
      () async {
        final store = createStore();
        final original = _skill(
          instructions: 'Do not place this text in the index.',
        );
        await store.saveSkill(original, mode: AiSkillSaveMode.createOnly);
        store.dispose();

        final index = File(path.join(directory.path, 'index.v1.json'));
        final indexText = await index.readAsString();
        expect(indexText, isNot(contains(original.instructions)));
        expect(indexText, contains(original.name));

        final reopened = createStore();
        addTearDown(reopened.dispose);
        final metadata = await reopened.getSkills();
        expect(metadata.single.id, original.id);
        final restored = await reopened.getSkill(original.id);
        expect(restored?.instructions, original.instructions);
        expect(restored?.contentHash, original.contentHash);
      },
    );

    test(
      'atomically switches body generations and removes the old body',
      () async {
        final store = createStore();
        addTearDown(store.dispose);
        final original = _skill(instructions: 'Original instructions');
        await store.saveSkill(original, mode: AiSkillSaveMode.createOnly);
        final revised = original.copyWith(
          instructions: 'Revised instructions',
          updatedAt: DateTime.utc(2026, 9, 5),
        );

        await store.saveSkill(
          revised,
          mode: AiSkillSaveMode.replaceOnly,
          expectedContentHash: original.contentHash,
        );

        final bodyFiles =
            await Directory(
              path.join(directory.path, 'bodies'),
            ).list().where((entity) => entity is File).toList();
        expect(bodyFiles, hasLength(1));
        expect(bodyFiles.single.path, contains(revised.contentHash));
        expect(
          (await store.getSkill(revised.id))?.instructions,
          'Revised instructions',
        );
        expect(
          directory
              .list(recursive: true)
              .where((entity) => path.basename(entity.path).contains('.tmp.')),
          emitsDone,
        );
      },
    );

    test(
      'detects body corruption without affecting metadata listing',
      () async {
        final store = createStore();
        addTearDown(store.dispose);
        final original = _skill();
        await store.saveSkill(original);
        final body =
            await Directory(
              path.join(directory.path, 'bodies'),
            ).list().where((entity) => entity is File).cast<File>().single;
        await body.writeAsString('Modified outside the store.');

        expect((await store.getSkills()).single.id, original.id);
        await expectLater(
          store.getSkill(original.id),
          throwsA(
            isA<AiSkillStoreException>().having(
              (error) => error.code,
              'code',
              AiSkillStoreErrorCode.corruptData,
            ),
          ),
        );
      },
    );

    test('rejects symbolic-link traversal in the bodies directory', () async {
      if (Platform.isWindows) return;
      final outside = await Directory.systemTemp.createTemp(
        'nexecute-skills-outside-',
      );
      addTearDown(() async {
        if (await outside.exists()) await outside.delete(recursive: true);
      });
      await Link(
        path.join(directory.path, 'bodies'),
      ).create(outside.path, recursive: false);
      final store = createStore();
      addTearDown(store.dispose);

      await expectLater(
        store.saveSkill(_skill()),
        throwsA(
          isA<AiSkillStoreException>().having(
            (error) => error.code,
            'code',
            AiSkillStoreErrorCode.corruptData,
          ),
        ),
      );
      expect(await outside.list().isEmpty, isTrue);
    });

    test('rejects a symbolic-link storage root', () async {
      if (Platform.isWindows) return;
      final outside = await Directory.systemTemp.createTemp(
        'nexecute-skills-root-outside-',
      );
      addTearDown(() async {
        if (await outside.exists()) await outside.delete(recursive: true);
      });
      await directory.delete();
      await Link(directory.path).create(outside.path);
      final store = createStore();
      addTearDown(store.dispose);

      await expectLater(
        store.getSkills(),
        _storeError(AiSkillStoreErrorCode.corruptData),
      );
      expect(await outside.list().isEmpty, isTrue);
    });

    test('rejects malformed indexes and duplicate IDs', () async {
      final skill = _skill();
      final metadata = {
        'schemaVersion': skill.schemaVersion,
        'id': skill.id,
        'name': skill.name,
        'description': skill.description,
        'isEnabled': skill.isEnabled,
        'outputMode': skill.outputMode.name,
        'contentHash': skill.contentHash,
        'createdAt': skill.createdAt.toIso8601String(),
        'updatedAt': skill.updatedAt.toIso8601String(),
      };
      await File(path.join(directory.path, 'index.v1.json')).writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'skills': [metadata, metadata],
        }),
      );
      final store = createStore();
      addTearDown(store.dispose);

      await expectLater(
        store.getSkills(),
        throwsA(
          isA<AiSkillStoreException>().having(
            (error) => error.code,
            'code',
            AiSkillStoreErrorCode.corruptData,
          ),
        ),
      );
    });
  });

  test(
    'unavailable store fails explicitly without construction side effects',
    () async {
      const store = UnavailableAiSkillStore();
      expect(store.isAvailable, isFalse);
      await expectLater(
        store.getSkills(),
        throwsA(
          isA<AiSkillStoreException>().having(
            (error) => error.code,
            'code',
            AiSkillStoreErrorCode.unavailable,
          ),
        ),
      );
    },
  );

  test(
    'filesystem store defers and normalizes directory-provider failure',
    () async {
      var providerCalled = false;
      final store = FileSystemAiSkillStore(
        directoryProvider: () async {
          providerCalled = true;
          throw StateError('platform directory unavailable');
        },
      );
      addTearDown(store.dispose);

      expect(providerCalled, isFalse);
      await expectLater(
        store.getSkills(),
        _storeError(AiSkillStoreErrorCode.unavailable),
      );
      expect(providerCalled, isTrue);
    },
  );
}

void _skillStoreContract(AiSkillStore Function() createStore) {
  test('creates, lists, watches, updates, and deletes skills', () async {
    final store = createStore();
    addTearDown(store.dispose);
    final emissions = <List<AiSkillMetadata>>[];
    final subscription = store.watchSkills().listen(emissions.add);
    addTearDown(subscription.cancel);
    await Future<void>.delayed(Duration.zero);

    final original = _skill();
    await store.saveSkill(original, mode: AiSkillSaveMode.createOnly);
    final revised = original.copyWith(
      name: 'Finnish language',
      isEnabled: false,
      updatedAt: DateTime.utc(2026, 9, 5),
    );
    await store.saveSkill(
      revised,
      mode: AiSkillSaveMode.replaceOnly,
      expectedContentHash: original.contentHash,
    );
    await Future<void>.delayed(Duration.zero);

    expect(emissions.first, isEmpty);
    expect(emissions[1].single.name, original.name);
    expect(emissions.last.single.name, revised.name);
    expect(() => emissions.last.clear(), throwsUnsupportedError);
    expect((await store.getSkills()).single.isEnabled, isFalse);
    expect((await store.getSkill(original.id))?.name, revised.name);
    expect((await store.searchSkills('FINNISH')).single.id, original.id);
    expect(await store.searchSkills('missing'), isEmpty);

    await store.deleteSkill(
      original.id,
      expectedContentHash: revised.contentHash,
    );
    expect(await store.getSkills(), isEmpty);
  });

  test(
    'enforces create, replace, and optimistic concurrency conflicts',
    () async {
      final store = createStore();
      addTearDown(store.dispose);
      final original = _skill();

      await expectLater(
        store.saveSkill(original, mode: AiSkillSaveMode.replaceOnly),
        _storeError(AiSkillStoreErrorCode.notFound),
      );
      await store.saveSkill(original, mode: AiSkillSaveMode.createOnly);
      await expectLater(
        store.saveSkill(original, mode: AiSkillSaveMode.createOnly),
        _storeError(AiSkillStoreErrorCode.conflict),
      );
      await expectLater(
        store.saveSkill(
          original.copyWith(updatedAt: DateTime.utc(2026, 9, 5)),
          mode: AiSkillSaveMode.replaceOnly,
          expectedContentHash: List.filled(64, '0').join(),
        ),
        _storeError(AiSkillStoreErrorCode.conflict),
      );
      await expectLater(
        store.deleteSkill(
          original.id,
          expectedContentHash: List.filled(64, '0').join(),
        ),
        _storeError(AiSkillStoreErrorCode.conflict),
      );
    },
  );
}

Matcher _storeError(AiSkillStoreErrorCode code) => throwsA(
  isA<AiSkillStoreException>().having((error) => error.code, 'code', code),
);

AiSkill _skill({String instructions = 'Vastaa selkeällä suomen kielellä.'}) =>
    AiSkill(
      id: 'suomen-kieli',
      name: 'Suomen kieli',
      description: 'Suomenkielinen kirjoitusapu.',
      instructions: instructions,
      createdAt: DateTime.utc(2026, 9, 4),
      updatedAt: DateTime.utc(2026, 9, 4),
    );
