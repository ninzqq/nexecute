import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:nexecute/ai/domain/ai_skill.dart';
import 'package:nexecute/ai/infrastructure/ai_skill_markdown_codec.dart';
import 'package:nexecute/ai/repositories/ai_skill_store.dart';
import 'package:path/path.dart' as path;

typedef AiSkillDirectoryProvider = Future<Directory> Function();

class FileSystemAiSkillStore implements AiSkillStore {
  FileSystemAiSkillStore({required AiSkillDirectoryProvider directoryProvider})
    : _directoryProvider = directoryProvider;

  static const _indexSchemaVersion = 1;
  static const _indexFileName = 'index.v1.json';
  static const _bodiesDirectoryName = 'bodies';
  static const _maxIndexBytes = 8 * 1024 * 1024;
  static const _maxSkills = 10000;

  final AiSkillDirectoryProvider _directoryProvider;
  final LinkedHashMap<String, AiSkillMetadata> _metadata = LinkedHashMap();
  final _skillsController = StreamController<List<AiSkillMetadata>>.broadcast();
  Future<void>? _loadFuture;
  Future<Directory>? _rootFuture;
  Future<void> _mutationTail = Future.value();
  var _temporaryCounter = 0;
  var _disposed = false;

  @override
  bool get isAvailable => true;

  @override
  Stream<List<AiSkillMetadata>> watchSkills() async* {
    yield await getSkills();
    yield* _skillsController.stream;
  }

  @override
  Future<List<AiSkillMetadata>> getSkills() async {
    await _ensureLoaded();
    return _metadataSnapshot();
  }

  @override
  Future<List<AiSkillMetadata>> searchSkills(String query) async {
    final values = await getSkills();
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

  @override
  Future<AiSkill?> getSkill(String skillId) => _schedule(() async {
    await _ensureLoaded();
    final metadata = _metadata[skillId];
    if (metadata == null) return null;
    try {
      final root = await _root();
      await _ensureStorageDirectories(root);
      final file = _bodyFile(root, metadata);
      await _rejectLink(file.path, expectedType: FileSystemEntityType.file);
      final bytes = await file.readAsBytes();
      if (bytes.length > aiMaxSkillDocumentBytes) {
        throw const AiSkillStoreException(
          AiSkillStoreErrorCode.corruptData,
          'A stored skill body exceeds the size limit.',
        );
      }
      final instructions = utf8.decode(bytes, allowMalformed: false);
      final skill = AiSkill(
        schemaVersion: metadata.schemaVersion,
        id: metadata.id,
        name: metadata.name,
        description: metadata.description,
        instructions: instructions,
        isEnabled: metadata.isEnabled,
        outputMode: metadata.outputMode,
        createdAt: metadata.createdAt,
        updatedAt: metadata.updatedAt,
      );
      if (skill.contentHash != metadata.contentHash) {
        throw const AiSkillStoreException(
          AiSkillStoreErrorCode.corruptData,
          'The stored skill body does not match its metadata.',
        );
      }
      return skill;
    } on AiSkillStoreException {
      rethrow;
    } on FileSystemException catch (error) {
      throw AiSkillStoreException(
        AiSkillStoreErrorCode.ioFailure,
        'The stored skill could not be read.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw AiSkillStoreException(
        AiSkillStoreErrorCode.corruptData,
        'The stored skill body is invalid.',
        cause: error,
      );
    }
  });

  @override
  Future<void> saveSkill(
    AiSkill skill, {
    AiSkillSaveMode mode = AiSkillSaveMode.upsert,
    String? expectedContentHash,
  }) => _schedule(() async {
    await _ensureLoaded();
    final existing = _metadata[skill.id];
    _validateSave(
      skill.id,
      existing: existing,
      mode: mode,
      expectedContentHash: expectedContentHash,
    );
    if (existing == null && _metadata.length >= _maxSkills) {
      throw const AiSkillStoreException(
        AiSkillStoreErrorCode.ioFailure,
        'The local skill count limit has been reached.',
      );
    }

    try {
      final root = await _root();
      await _ensureStorageDirectories(root);
      final nextMetadata = AiSkillMetadata.fromSkill(skill);
      final bodyFile = _bodyFile(root, nextMetadata);
      final bodyType = await FileSystemEntity.type(
        bodyFile.path,
        followLinks: false,
      );
      if (bodyType == FileSystemEntityType.link) {
        throw const AiSkillStoreException(
          AiSkillStoreErrorCode.corruptData,
          'A skill body path is an unexpected symbolic link.',
        );
      }
      if (bodyType != FileSystemEntityType.notFound &&
          bodyType != FileSystemEntityType.file) {
        throw const AiSkillStoreException(
          AiSkillStoreErrorCode.corruptData,
          'A skill body path is not a regular file.',
        );
      }
      await _atomicWrite(
        bodyFile,
        utf8.encode(_normalizeLineEndings(skill.instructions)),
      );

      final next = LinkedHashMap<String, AiSkillMetadata>.of(_metadata)
        ..[skill.id] = nextMetadata;
      await _writeIndex(root, next.values);
      _metadata
        ..clear()
        ..addAll(next);
      _emit();
      if (existing != null && existing.contentHash != skill.contentHash) {
        await _deleteBodyBestEffort(root, existing);
      }
    } on AiSkillStoreException {
      rethrow;
    } on FileSystemException catch (error) {
      throw AiSkillStoreException(
        AiSkillStoreErrorCode.ioFailure,
        'The skill could not be saved.',
        cause: error,
      );
    }
  });

  @override
  Future<void> deleteSkill(String skillId, {String? expectedContentHash}) =>
      _schedule(() async {
        await _ensureLoaded();
        final existing = _metadata[skillId];
        if (existing == null) return;
        if (expectedContentHash != null &&
            existing.contentHash != expectedContentHash) {
          throw const AiSkillStoreException(
            AiSkillStoreErrorCode.conflict,
            'The skill changed before it could be deleted.',
          );
        }
        try {
          final root = await _root();
          final next = LinkedHashMap<String, AiSkillMetadata>.of(_metadata)
            ..remove(skillId);
          await _writeIndex(root, next.values);
          _metadata
            ..clear()
            ..addAll(next);
          _emit();
          await _deleteBodyBestEffort(root, existing);
        } on AiSkillStoreException {
          rethrow;
        } on FileSystemException catch (error) {
          throw AiSkillStoreException(
            AiSkillStoreErrorCode.ioFailure,
            'The skill could not be deleted.',
            cause: error,
          );
        }
      });

  Future<void> _ensureLoaded() async {
    final existing = _loadFuture;
    if (existing != null) return existing;
    final current = _load();
    _loadFuture = current;
    try {
      await current;
    } catch (_) {
      if (identical(_loadFuture, current)) _loadFuture = null;
      rethrow;
    }
  }

  Future<void> _load() async {
    try {
      final root = await _root();
      final indexFile = File(path.join(root.path, _indexFileName));
      final indexType = await FileSystemEntity.type(
        indexFile.path,
        followLinks: false,
      );
      if (indexType == FileSystemEntityType.notFound) {
        _metadata.clear();
        return;
      }
      if (indexType == FileSystemEntityType.link ||
          indexType != FileSystemEntityType.file) {
        throw const AiSkillStoreException(
          AiSkillStoreErrorCode.corruptData,
          'The skill metadata index is not a regular file.',
        );
      }
      final bytes = await indexFile.readAsBytes();
      if (bytes.length > _maxIndexBytes) {
        throw const AiSkillStoreException(
          AiSkillStoreErrorCode.corruptData,
          'The skill metadata index exceeds the size limit.',
        );
      }
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      final loaded = _decodeIndex(decoded);
      _metadata
        ..clear()
        ..addEntries(loaded.map((item) => MapEntry(item.id, item)));
    } on AiSkillStoreException {
      rethrow;
    } on FileSystemException catch (error) {
      throw AiSkillStoreException(
        AiSkillStoreErrorCode.ioFailure,
        'The skill metadata index could not be read.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw AiSkillStoreException(
        AiSkillStoreErrorCode.corruptData,
        'The skill metadata index is invalid.',
        cause: error,
      );
    }
  }

  Future<Directory> _root() async {
    final existing = _rootFuture;
    if (existing != null) return existing;
    final current = _prepareRoot();
    _rootFuture = current;
    try {
      return await current;
    } catch (_) {
      if (identical(_rootFuture, current)) _rootFuture = null;
      rethrow;
    }
  }

  Future<Directory> _prepareRoot() async {
    try {
      final provided = await _directoryProvider();
      final absolute = Directory(path.normalize(path.absolute(provided.path)));
      final type = await FileSystemEntity.type(
        absolute.path,
        followLinks: false,
      );
      if (type == FileSystemEntityType.link) {
        throw const AiSkillStoreException(
          AiSkillStoreErrorCode.corruptData,
          'The skill storage root must not be a symbolic link.',
        );
      }
      if (type == FileSystemEntityType.notFound) {
        await absolute.create(recursive: true);
      } else if (type != FileSystemEntityType.directory) {
        throw const AiSkillStoreException(
          AiSkillStoreErrorCode.corruptData,
          'The skill storage root is not a directory.',
        );
      }
      return absolute;
    } on AiSkillStoreException {
      rethrow;
    } on FileSystemException catch (error) {
      throw AiSkillStoreException(
        AiSkillStoreErrorCode.ioFailure,
        'AI skill storage is unavailable.',
        cause: error,
      );
    } catch (error) {
      throw AiSkillStoreException(
        AiSkillStoreErrorCode.unavailable,
        'AI skill storage is unavailable.',
        cause: error,
      );
    }
  }

  Future<void> _ensureStorageDirectories(Directory root) async {
    final rootType = await FileSystemEntity.type(root.path, followLinks: false);
    if (rootType == FileSystemEntityType.link ||
        rootType != FileSystemEntityType.directory) {
      throw const AiSkillStoreException(
        AiSkillStoreErrorCode.corruptData,
        'The skill storage root is no longer a regular directory.',
      );
    }
    final bodies = Directory(path.join(root.path, _bodiesDirectoryName));
    final type = await FileSystemEntity.type(bodies.path, followLinks: false);
    if (type == FileSystemEntityType.link) {
      throw const AiSkillStoreException(
        AiSkillStoreErrorCode.corruptData,
        'The skill bodies directory must not be a symbolic link.',
      );
    }
    if (type == FileSystemEntityType.notFound) {
      await bodies.create();
    } else if (type != FileSystemEntityType.directory) {
      throw const AiSkillStoreException(
        AiSkillStoreErrorCode.corruptData,
        'The skill bodies path is not a directory.',
      );
    }
  }

  File _bodyFile(Directory root, AiSkillMetadata metadata) {
    final bodiesPath = path.join(root.path, _bodiesDirectoryName);
    final bodyPath = path.normalize(
      path.join(bodiesPath, '${metadata.id}.${metadata.contentHash}.md'),
    );
    if (!path.isWithin(bodiesPath, bodyPath)) {
      throw const AiSkillStoreException(
        AiSkillStoreErrorCode.corruptData,
        'The skill body path escaped its storage directory.',
      );
    }
    return File(bodyPath);
  }

  Future<void> _rejectLink(
    String filePath, {
    required FileSystemEntityType expectedType,
  }) async {
    final type = await FileSystemEntity.type(filePath, followLinks: false);
    if (type == FileSystemEntityType.link) {
      throw const AiSkillStoreException(
        AiSkillStoreErrorCode.corruptData,
        'A stored skill path is an unexpected symbolic link.',
      );
    }
    if (type != expectedType) {
      throw const AiSkillStoreException(
        AiSkillStoreErrorCode.corruptData,
        'A stored skill file is missing or invalid.',
      );
    }
  }

  Future<void> _writeIndex(
    Directory root,
    Iterable<AiSkillMetadata> metadata,
  ) async {
    final rootType = await FileSystemEntity.type(root.path, followLinks: false);
    if (rootType == FileSystemEntityType.link ||
        rootType != FileSystemEntityType.directory) {
      throw const AiSkillStoreException(
        AiSkillStoreErrorCode.corruptData,
        'The skill storage root is no longer a regular directory.',
      );
    }
    final sorted = metadata.toList()..sort(_compareMetadata);
    final encoded = utf8.encode(
      jsonEncode({
        'schemaVersion': _indexSchemaVersion,
        'skills': sorted.map(_metadataToJson).toList(growable: false),
      }),
    );
    if (encoded.length > _maxIndexBytes) {
      throw const AiSkillStoreException(
        AiSkillStoreErrorCode.ioFailure,
        'The skill metadata index exceeds the size limit.',
      );
    }
    await _atomicWrite(File(path.join(root.path, _indexFileName)), encoded);
  }

  Future<void> _atomicWrite(File destination, List<int> bytes) async {
    final temporary = File(
      '${destination.path}.tmp.${DateTime.now().microsecondsSinceEpoch}.'
      '${_temporaryCounter++}',
    );
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(destination.path);
    } finally {
      if (await temporary.exists()) {
        try {
          await temporary.delete();
        } on FileSystemException {
          // A failed temporary-file cleanup must not hide the original result.
        }
      }
    }
  }

  Future<void> _deleteBodyBestEffort(
    Directory root,
    AiSkillMetadata metadata,
  ) async {
    final file = _bodyFile(root, metadata);
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.file) {
      try {
        await file.delete();
      } on FileSystemException {
        // Immutable orphan bodies are safe and can be cleaned up later.
      }
    }
  }

  Future<T> _schedule<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _mutationTail = _mutationTail.then((_) async {
      try {
        if (_disposed) {
          throw const AiSkillStoreException(
            AiSkillStoreErrorCode.unavailable,
            'AI skill storage has been disposed.',
          );
        }
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  List<AiSkillMetadata> _metadataSnapshot() {
    final values = _metadata.values.toList()..sort(_compareMetadata);
    return List.unmodifiable(values);
  }

  void _emit() {
    if (!_disposed) _skillsController.add(_metadataSnapshot());
  }

  @override
  void dispose() {
    _disposed = true;
    _skillsController.close();
  }
}

List<AiSkillMetadata> _decodeIndex(Object? value) {
  if (value is! Map<String, dynamic> ||
      value.keys.toSet().difference(const {
        'schemaVersion',
        'skills',
      }).isNotEmpty ||
      value['schemaVersion'] != FileSystemAiSkillStore._indexSchemaVersion ||
      value['skills'] is! List) {
    throw const FormatException('Invalid skill metadata index root.');
  }
  final values = value['skills'] as List;
  if (values.length > FileSystemAiSkillStore._maxSkills) {
    throw const FormatException('Too many skills in metadata index.');
  }
  final result = <AiSkillMetadata>[];
  final ids = <String>{};
  for (final value in values) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid skill metadata entry.');
    }
    final expectedFields = const {
      'schemaVersion',
      'id',
      'name',
      'description',
      'isEnabled',
      'outputMode',
      'contentHash',
      'createdAt',
      'updatedAt',
    };
    if (value.keys.toSet().difference(expectedFields).isNotEmpty ||
        expectedFields.difference(value.keys.toSet()).isNotEmpty) {
      throw const FormatException('Invalid skill metadata fields.');
    }
    final id = _requiredString(value, 'id');
    if (!ids.add(id)) throw const FormatException('Duplicate skill id.');
    result.add(
      AiSkillMetadata(
        schemaVersion: _requiredInt(value, 'schemaVersion'),
        id: id,
        name: _requiredString(value, 'name'),
        description: _requiredString(value, 'description'),
        isEnabled: _requiredBool(value, 'isEnabled'),
        outputMode: _outputMode(_requiredString(value, 'outputMode')),
        contentHash: _requiredString(value, 'contentHash'),
        createdAt: _requiredDate(value, 'createdAt'),
        updatedAt: _requiredDate(value, 'updatedAt'),
      ),
    );
  }
  return result;
}

Map<String, Object?> _metadataToJson(AiSkillMetadata value) => {
  'schemaVersion': value.schemaVersion,
  'id': value.id,
  'name': value.name,
  'description': value.description,
  'isEnabled': value.isEnabled,
  'outputMode': value.outputMode.name,
  'contentHash': value.contentHash,
  'createdAt': value.createdAt.toIso8601String(),
  'updatedAt': value.updatedAt.toIso8601String(),
};

void _validateSave(
  String skillId, {
  required AiSkillMetadata? existing,
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

String _requiredString(Map<String, dynamic> value, String key) {
  final result = value[key];
  if (result is! String) throw FormatException('Invalid $key.');
  return result;
}

int _requiredInt(Map<String, dynamic> value, String key) {
  final result = value[key];
  if (result is! int) throw FormatException('Invalid $key.');
  return result;
}

bool _requiredBool(Map<String, dynamic> value, String key) {
  final result = value[key];
  if (result is! bool) throw FormatException('Invalid $key.');
  return result;
}

DateTime _requiredDate(Map<String, dynamic> value, String key) {
  final source = _requiredString(value, key);
  final result = DateTime.tryParse(source);
  if (result == null) throw FormatException('Invalid $key.');
  return result;
}

AiSkillOutputMode _outputMode(String name) {
  for (final value in AiSkillOutputMode.values) {
    if (value.name == name) return value;
  }
  throw FormatException('Invalid outputMode: $name.');
}

int _compareMetadata(AiSkillMetadata left, AiSkillMetadata right) {
  final byName = left.name.toLowerCase().compareTo(right.name.toLowerCase());
  return byName != 0 ? byName : left.id.compareTo(right.id);
}

String _normalizeLineEndings(String value) =>
    value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
