import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  AiSkill skill({
    String id = 'suomen-kieli',
    String name = 'Suomen kieli',
    String description = 'Suomenkielisen tekstin tuottaminen ja tarkistaminen.',
    String instructions = 'Vastaa aina selkeällä suomen kielellä.',
    bool isEnabled = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => AiSkill(
    id: id,
    name: name,
    description: description,
    instructions: instructions,
    isEnabled: isEnabled,
    createdAt: createdAt ?? DateTime.utc(2026, 9, 4),
    updatedAt: updatedAt ?? DateTime.utc(2026, 9, 4),
  );

  test('defines a bounded text-only portable skill', () {
    final value = skill();

    expect(value.schemaVersion, aiSkillSchemaVersion);
    expect(value.id, 'suomen-kieli');
    expect(value.outputMode, AiSkillOutputMode.text);
    expect(value.isEnabled, isTrue);
    expect(value.contentHash, matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(AiSkillDocumentContract.fileName, 'SKILL.md');
    expect(AiSkillDocumentContract.supportedFrontmatterFields, const {
      'schemaVersion',
      'id',
      'name',
      'description',
      'outputMode',
    });
    expect(
      AiSkillDocumentContract.requiredFrontmatterFields,
      AiSkillDocumentContract.supportedFrontmatterFields,
    );
  });

  test('content hash changes only with portable skill content', () {
    final original = skill();
    final localStateChanged = original.copyWith(
      isEnabled: false,
      updatedAt: DateTime.utc(2026, 9, 5),
    );
    final instructionsChanged = original.copyWith(
      instructions: '${original.instructions}\nVältä anglismeja.',
      updatedAt: DateTime.utc(2026, 9, 5),
    );

    expect(localStateChanged.contentHash, original.contentHash);
    expect(instructionsChanged.contentHash, isNot(original.contentHash));
    expect(
      original.copyWith(instructions: 'First\r\nSecond').contentHash,
      original.copyWith(instructions: 'First\nSecond').contentHash,
    );
  });

  test('metadata is validated without retaining the instruction body', () {
    final value = skill();
    final metadata = AiSkillMetadata.fromSkill(value);

    expect(metadata.id, value.id);
    expect(metadata.contentHash, value.contentHash);
    expect(metadata.isEnabled, value.isEnabled);
    expect(
      () => AiSkillMetadata(
        id: value.id,
        name: value.name,
        description: value.description,
        isEnabled: value.isEnabled,
        outputMode: value.outputMode,
        contentHash: 'invalid',
        createdAt: value.createdAt,
        updatedAt: value.updatedAt,
      ),
      throwsA(
        isA<AiSkillValidationException>().having(
          (error) => error.code,
          'code',
          AiSkillValidationErrorCode.invalidContentHash,
        ),
      ),
    );
  });

  test('accepts a Finnish instruction body up to 16000 characters', () {
    final value = skill(
      instructions: List.filled(aiMaxSkillInstructionCharacters, 'ä').join(),
    );

    expect(value.instructions.runes.length, aiMaxSkillInstructionCharacters);
  });

  test('rejects unsupported versions and invalid identifiers', () {
    expect(
      () => AiSkill(
        schemaVersion: 2,
        id: 'suomen-kieli',
        name: 'Suomen kieli',
        description: 'Kuvaus',
        instructions: 'Ohje',
        createdAt: DateTime.utc(2026, 9, 4),
        updatedAt: DateTime.utc(2026, 9, 4),
      ),
      throwsA(
        isA<AiSkillValidationException>().having(
          (error) => error.code,
          'code',
          AiSkillValidationErrorCode.unsupportedVersion,
        ),
      ),
    );
    expect(
      () => skill(id: '../Suomen kieli'),
      throwsA(
        isA<AiSkillValidationException>().having(
          (error) => error.code,
          'code',
          AiSkillValidationErrorCode.invalidId,
        ),
      ),
    );
  });

  test('rejects invalid metadata and instruction bodies', () {
    expect(
      () => skill(name: ' Suomen kieli'),
      throwsA(
        isA<AiSkillValidationException>().having(
          (error) => error.code,
          'code',
          AiSkillValidationErrorCode.invalidName,
        ),
      ),
    );
    expect(
      () => skill(description: 'First line\nSecond line'),
      throwsA(
        isA<AiSkillValidationException>().having(
          (error) => error.code,
          'code',
          AiSkillValidationErrorCode.invalidDescription,
        ),
      ),
    );
    expect(
      () => skill(instructions: '   '),
      throwsA(
        isA<AiSkillValidationException>().having(
          (error) => error.code,
          'code',
          AiSkillValidationErrorCode.invalidInstructions,
        ),
      ),
    );
    expect(
      () => skill(
        instructions:
            List.filled(aiMaxSkillInstructionCharacters + 1, 'x').join(),
      ),
      throwsA(
        isA<AiSkillValidationException>().having(
          (error) => error.code,
          'code',
          AiSkillValidationErrorCode.invalidInstructions,
        ),
      ),
    );
  });

  test('rejects malformed Unicode and reversed timestamps', () {
    expect(
      () => skill(instructions: String.fromCharCode(0xd800)),
      throwsA(
        isA<AiSkillValidationException>().having(
          (error) => error.code,
          'code',
          AiSkillValidationErrorCode.invalidInstructions,
        ),
      ),
    );
    expect(
      () => skill(
        createdAt: DateTime.utc(2026, 9, 5),
        updatedAt: DateTime.utc(2026, 9, 4),
      ),
      throwsA(
        isA<AiSkillValidationException>().having(
          (error) => error.code,
          'code',
          AiSkillValidationErrorCode.invalidTimestamp,
        ),
      ),
    );
  });
}
