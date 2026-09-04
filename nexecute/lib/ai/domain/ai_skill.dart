import 'dart:convert';

import 'package:crypto/crypto.dart';

const aiSkillSchemaVersion = 1;
const aiMaxSkillIdCharacters = 64;
const aiMaxSkillNameCharacters = 100;
const aiMaxSkillDescriptionCharacters = 500;
const aiMaxSkillInstructionCharacters = 16000;

/// The fields accepted in version 1 `SKILL.md` frontmatter.
///
/// Storage-only state such as [AiSkill.isEnabled] and timestamps deliberately
/// stays outside the portable document. Importers must reject unknown fields
/// until a later schema version defines their behavior.
abstract final class AiSkillDocumentContract {
  static const fileName = 'SKILL.md';
  static const supportedFrontmatterFields = <String>{
    'schemaVersion',
    'id',
    'name',
    'description',
    'outputMode',
  };
  static const requiredFrontmatterFields = supportedFrontmatterFields;
}

/// Version 1 skills can affect text generation only.
///
/// Tool identifiers and structured output contracts will remain app-owned
/// capabilities if they are added in a later schema version.
enum AiSkillOutputMode { text }

enum AiSkillValidationErrorCode {
  unsupportedVersion,
  invalidId,
  invalidName,
  invalidDescription,
  invalidInstructions,
  invalidTimestamp,
}

final class AiSkillValidationException extends FormatException {
  const AiSkillValidationException(this.code, String message) : super(message);

  final AiSkillValidationErrorCode code;
}

/// A reusable, user-authored instruction set.
///
/// This type intentionally contains no executable hooks, tool definitions,
/// data permissions, network configuration, or repository bindings. An
/// [AiSkill] can refine assistant behavior only after the application composes
/// it beneath its immutable policy and request authorization boundaries.
final class AiSkill {
  factory AiSkill({
    int schemaVersion = aiSkillSchemaVersion,
    required String id,
    required String name,
    required String description,
    required String instructions,
    bool isEnabled = true,
    AiSkillOutputMode outputMode = AiSkillOutputMode.text,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    _validateSchemaVersion(schemaVersion);
    _validateId(id);
    _validateSingleLineText(
      name,
      fieldName: 'name',
      maximumCharacters: aiMaxSkillNameCharacters,
      errorCode: AiSkillValidationErrorCode.invalidName,
    );
    _validateSingleLineText(
      description,
      fieldName: 'description',
      maximumCharacters: aiMaxSkillDescriptionCharacters,
      errorCode: AiSkillValidationErrorCode.invalidDescription,
    );
    _validateInstructions(instructions);
    if (updatedAt.isBefore(createdAt)) {
      throw const AiSkillValidationException(
        AiSkillValidationErrorCode.invalidTimestamp,
        'Skill updatedAt must not be before createdAt.',
      );
    }

    return AiSkill._(
      schemaVersion: schemaVersion,
      id: id,
      name: name,
      description: description,
      instructions: instructions,
      isEnabled: isEnabled,
      outputMode: outputMode,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  AiSkill._({
    required this.schemaVersion,
    required this.id,
    required this.name,
    required this.description,
    required this.instructions,
    required this.isEnabled,
    required this.outputMode,
    required this.createdAt,
    required this.updatedAt,
  }) : contentHash = _contentHash(
         schemaVersion: schemaVersion,
         id: id,
         name: name,
         description: description,
         instructions: instructions,
         outputMode: outputMode,
       );

  final int schemaVersion;
  final String id;
  final String name;
  final String description;
  final String instructions;
  final bool isEnabled;
  final AiSkillOutputMode outputMode;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Stable SHA-256 identity for the portable skill content.
  ///
  /// Local enabled state and timestamps are excluded, so importing the same
  /// `SKILL.md` on another device produces the same hash.
  final String contentHash;

  AiSkill copyWith({
    String? id,
    String? name,
    String? description,
    String? instructions,
    bool? isEnabled,
    AiSkillOutputMode? outputMode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => AiSkill(
    schemaVersion: schemaVersion,
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    instructions: instructions ?? this.instructions,
    isEnabled: isEnabled ?? this.isEnabled,
    outputMode: outputMode ?? this.outputMode,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

void _validateSchemaVersion(int value) {
  if (value != aiSkillSchemaVersion) {
    throw AiSkillValidationException(
      AiSkillValidationErrorCode.unsupportedVersion,
      'Unsupported skill schema version: $value.',
    );
  }
}

void _validateId(String value) {
  if (!_isWellFormedUnicode(value) ||
      value.length > aiMaxSkillIdCharacters ||
      !RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(value)) {
    throw const AiSkillValidationException(
      AiSkillValidationErrorCode.invalidId,
      'Skill id must be a lowercase, hyphen-separated identifier of at most '
      '$aiMaxSkillIdCharacters characters.',
    );
  }
}

void _validateSingleLineText(
  String value, {
  required String fieldName,
  required int maximumCharacters,
  required AiSkillValidationErrorCode errorCode,
}) {
  if (!_isWellFormedUnicode(value) ||
      value.trim() != value ||
      value.isEmpty ||
      value.runes.length > maximumCharacters ||
      _containsDisallowedMetadataCharacter(value)) {
    throw AiSkillValidationException(
      errorCode,
      'Skill $fieldName must be one trimmed UTF-8 line of 1 to '
      '$maximumCharacters characters.',
    );
  }
}

void _validateInstructions(String value) {
  if (!_isWellFormedUnicode(value) ||
      value.trim().isEmpty ||
      value.runes.length > aiMaxSkillInstructionCharacters ||
      _containsDisallowedInstructionCharacter(value)) {
    throw const AiSkillValidationException(
      AiSkillValidationErrorCode.invalidInstructions,
      'Skill instructions must be valid UTF-8 Markdown containing 1 to '
      '$aiMaxSkillInstructionCharacters characters.',
    );
  }
}

bool _containsDisallowedMetadataCharacter(String value) =>
    value.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f);

bool _containsDisallowedInstructionCharacter(String value) =>
    value.codeUnits.any(
      (unit) =>
          (unit < 0x20 && unit != 0x09 && unit != 0x0a && unit != 0x0d) ||
          unit == 0x7f,
    );

bool _isWellFormedUnicode(String value) {
  final units = value.codeUnits;
  for (var index = 0; index < units.length; index++) {
    final unit = units[index];
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++index >= units.length) return false;
      final trailing = units[index];
      if (trailing < 0xdc00 || trailing > 0xdfff) return false;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      return false;
    }
  }
  return true;
}

String _contentHash({
  required int schemaVersion,
  required String id,
  required String name,
  required String description,
  required String instructions,
  required AiSkillOutputMode outputMode,
}) =>
    sha256
        .convert(
          utf8.encode(
            jsonEncode([
              schemaVersion,
              id,
              name,
              description,
              outputMode.name,
              _normalizeLineEndings(instructions),
            ]),
          ),
        )
        .toString();

String _normalizeLineEndings(String value) =>
    value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
