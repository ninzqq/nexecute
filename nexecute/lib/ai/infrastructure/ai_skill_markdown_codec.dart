import 'dart:convert';
import 'dart:typed_data';

import 'package:nexecute/ai/domain/ai_skill.dart';
import 'package:yaml/yaml.dart';

const aiMaxSkillDocumentBytes = 131072;

enum AiSkillDocumentErrorCode {
  invalidFileName,
  documentTooLarge,
  invalidUtf8,
  malformedFrontmatter,
  unknownFrontmatterField,
  missingMetadata,
  unsupportedVersion,
  invalidMetadata,
  emptyInstructions,
  invalidInstructions,
}

final class AiSkillDocumentException extends FormatException {
  const AiSkillDocumentException(this.code, String message) : super(message);

  final AiSkillDocumentErrorCode code;
}

abstract final class AiSkillMarkdownCodec {
  static AiSkill decode(
    List<int> bytes, {
    required String sourceFileName,
    required DateTime importedAt,
    String? bodyOnlyId,
    String? bodyOnlyName,
    String? bodyOnlyDescription,
    bool isEnabled = true,
  }) {
    validateFileName(sourceFileName);
    if (bytes.length > aiMaxSkillDocumentBytes) {
      throw const AiSkillDocumentException(
        AiSkillDocumentErrorCode.documentTooLarge,
        'The skill document is too large.',
      );
    }

    final String decoded;
    try {
      decoded = utf8.decode(bytes, allowMalformed: false);
    } on FormatException catch (error) {
      throw AiSkillDocumentException(
        AiSkillDocumentErrorCode.invalidUtf8,
        'The skill document is not valid UTF-8: ${error.message}',
      );
    }
    final source = _normalizeLineEndings(
      decoded.startsWith('\ufeff') ? decoded.substring(1) : decoded,
    );
    final parsed = _parse(source);
    final metadata = parsed.metadata;

    final schemaVersion =
        metadata == null
            ? aiSkillSchemaVersion
            : _integer(metadata, 'schemaVersion');
    final id = metadata == null ? bodyOnlyId : _string(metadata, 'id');
    final name = metadata == null ? bodyOnlyName : _string(metadata, 'name');
    final description =
        metadata == null
            ? bodyOnlyDescription
            : _string(metadata, 'description');
    final outputModeName =
        metadata == null
            ? AiSkillOutputMode.text.name
            : _string(metadata, 'outputMode');
    if (id == null || name == null || description == null) {
      throw const AiSkillDocumentException(
        AiSkillDocumentErrorCode.missingMetadata,
        'A body-only skill requires an id, name, and description.',
      );
    }
    final outputMode = _outputMode(outputModeName);
    if (parsed.instructions.trim().isEmpty) {
      throw const AiSkillDocumentException(
        AiSkillDocumentErrorCode.emptyInstructions,
        'The skill instruction body is empty.',
      );
    }

    try {
      return AiSkill(
        schemaVersion: schemaVersion,
        id: id,
        name: name,
        description: description,
        instructions: parsed.instructions,
        isEnabled: isEnabled,
        outputMode: outputMode,
        createdAt: importedAt,
        updatedAt: importedAt,
      );
    } on AiSkillValidationException catch (error) {
      throw AiSkillDocumentException(switch (error.code) {
        AiSkillValidationErrorCode.unsupportedVersion =>
          AiSkillDocumentErrorCode.unsupportedVersion,
        AiSkillValidationErrorCode.invalidInstructions =>
          AiSkillDocumentErrorCode.invalidInstructions,
        _ => AiSkillDocumentErrorCode.invalidMetadata,
      }, error.message);
    }
  }

  static Uint8List encode(AiSkill skill) {
    final document = '''---
schemaVersion: ${skill.schemaVersion}
id: ${skill.id}
name: ${jsonEncode(skill.name)}
description: ${jsonEncode(skill.description)}
outputMode: ${skill.outputMode.name}
---
${_normalizeLineEndings(skill.instructions)}''';
    final bytes = Uint8List.fromList(utf8.encode(document));
    if (bytes.length > aiMaxSkillDocumentBytes) {
      throw const AiSkillDocumentException(
        AiSkillDocumentErrorCode.documentTooLarge,
        'The encoded skill document is too large.',
      );
    }
    return bytes;
  }

  static String validateFileName(String value) {
    if (value.contains('/') ||
        value.contains('\\') ||
        value.toLowerCase() != AiSkillDocumentContract.fileName.toLowerCase()) {
      throw const AiSkillDocumentException(
        AiSkillDocumentErrorCode.invalidFileName,
        'Skill imports must use the filename SKILL.md.',
      );
    }
    return AiSkillDocumentContract.fileName;
  }

  static _ParsedSkillDocument _parse(String source) {
    if (!source.startsWith('---\n')) {
      return _ParsedSkillDocument(instructions: source);
    }
    final closingDelimiter = source.indexOf('\n---\n', 4);
    if (closingDelimiter < 0) {
      throw const AiSkillDocumentException(
        AiSkillDocumentErrorCode.malformedFrontmatter,
        'The skill frontmatter has no closing delimiter.',
      );
    }
    final frontmatterSource = source.substring(4, closingDelimiter);
    _validateFrontmatterLines(frontmatterSource);
    final Object? yaml;
    try {
      yaml = loadYaml(frontmatterSource);
    } on YamlException catch (error) {
      throw AiSkillDocumentException(
        AiSkillDocumentErrorCode.malformedFrontmatter,
        'The skill frontmatter is malformed: ${error.message}',
      );
    }
    if (yaml is! YamlMap) {
      throw const AiSkillDocumentException(
        AiSkillDocumentErrorCode.malformedFrontmatter,
        'The skill frontmatter must be a mapping.',
      );
    }
    final metadata = <String, Object?>{};
    for (final entry in yaml.entries) {
      final key = entry.key;
      if (key is! String) {
        throw const AiSkillDocumentException(
          AiSkillDocumentErrorCode.malformedFrontmatter,
          'Every skill frontmatter key must be text.',
        );
      }
      if (!AiSkillDocumentContract.supportedFrontmatterFields.contains(key)) {
        throw AiSkillDocumentException(
          AiSkillDocumentErrorCode.unknownFrontmatterField,
          'Unknown skill frontmatter field: $key.',
        );
      }
      metadata[key] = entry.value;
    }
    final missing = AiSkillDocumentContract.requiredFrontmatterFields
        .difference(metadata.keys.toSet());
    if (missing.isNotEmpty) {
      final fields = missing.toList()..sort();
      throw AiSkillDocumentException(
        AiSkillDocumentErrorCode.missingMetadata,
        'Missing skill frontmatter fields: ${fields.join(', ')}.',
      );
    }
    return _ParsedSkillDocument(
      metadata: metadata,
      instructions: source.substring(closingDelimiter + 5),
    );
  }

  static void _validateFrontmatterLines(String source) {
    final keys = <String>{};
    for (final line in source.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      if (line != trimmed) {
        throw const AiSkillDocumentException(
          AiSkillDocumentErrorCode.malformedFrontmatter,
          'Skill frontmatter fields must not be nested or indented.',
        );
      }
      final separator = trimmed.indexOf(':');
      if (separator <= 0) {
        throw const AiSkillDocumentException(
          AiSkillDocumentErrorCode.malformedFrontmatter,
          'Every skill frontmatter field must use key: value syntax.',
        );
      }
      final key = trimmed.substring(0, separator);
      if (!RegExp(r'^[A-Za-z][A-Za-z0-9]*$').hasMatch(key) || !keys.add(key)) {
        throw const AiSkillDocumentException(
          AiSkillDocumentErrorCode.malformedFrontmatter,
          'Skill frontmatter contains an invalid or duplicate field.',
        );
      }
    }
  }

  static String _string(Map<String, Object?> values, String key) {
    final value = values[key];
    if (value is! String) {
      throw AiSkillDocumentException(
        AiSkillDocumentErrorCode.invalidMetadata,
        'Skill frontmatter $key must be text.',
      );
    }
    return value;
  }

  static int _integer(Map<String, Object?> values, String key) {
    final value = values[key];
    if (value is! int) {
      throw AiSkillDocumentException(
        AiSkillDocumentErrorCode.invalidMetadata,
        'Skill frontmatter $key must be an integer.',
      );
    }
    return value;
  }

  static AiSkillOutputMode _outputMode(String name) {
    for (final value in AiSkillOutputMode.values) {
      if (value.name == name) return value;
    }
    throw AiSkillDocumentException(
      AiSkillDocumentErrorCode.invalidMetadata,
      'Unsupported skill outputMode: $name.',
    );
  }
}

final class _ParsedSkillDocument {
  const _ParsedSkillDocument({required this.instructions, this.metadata});

  final String instructions;
  final Map<String, Object?>? metadata;
}

String _normalizeLineEndings(String value) =>
    value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
