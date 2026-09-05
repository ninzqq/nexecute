import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';

void main() {
  final importedAt = DateTime.utc(2026, 9, 5, 12);

  test('round-trips a frontmatter SKILL.md without executable semantics', () {
    final original = _skill(
      instructions: '''Use the supplied language rules.

```sh
echo "This remains inert Markdown"
```

[Reference](https://example.test/reference)''',
    );

    final restored = AiSkillMarkdownCodec.decode(
      AiSkillMarkdownCodec.encode(original),
      sourceFileName: 'SKILL.md',
      importedAt: importedAt,
      isEnabled: false,
    );

    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.description, original.description);
    expect(restored.instructions, original.instructions);
    expect(restored.outputMode, AiSkillOutputMode.text);
    expect(restored.isEnabled, isFalse);
    expect(restored.createdAt, importedAt);
    expect(restored.contentHash, original.contentHash);
  });

  test('accepts body-only Markdown when import metadata is supplied', () {
    final body = 'Tunnista käyttäjän pyyntö ja vastaa suomeksi.';

    final skill = AiSkillMarkdownCodec.decode(
      utf8.encode(body),
      sourceFileName: 'skill.MD',
      importedAt: importedAt,
      bodyOnlyId: 'suomen-kieli',
      bodyOnlyName: 'Suomen kieli',
      bodyOnlyDescription: 'Suomenkielinen kirjoitusapu.',
    );

    expect(skill.instructions, body);
    expect(skill.name, 'Suomen kieli');
  });

  test('imports a representative long Finnish skill intact', () {
    final instructions = List.filled(11000, 'ä').join();
    final skill = AiSkillMarkdownCodec.decode(
      utf8.encode(instructions),
      sourceFileName: 'SKILL.md',
      importedAt: importedAt,
      bodyOnlyId: 'suomen-kieli',
      bodyOnlyName: 'Suomen kieli',
      bodyOnlyDescription: 'Suomenkielinen kirjoitusapu.',
    );

    expect(skill.instructions.runes.length, 11000);
  });

  test('requires body-only metadata and every frontmatter field', () {
    expect(
      () => AiSkillMarkdownCodec.decode(
        utf8.encode('Instructions'),
        sourceFileName: 'SKILL.md',
        importedAt: importedAt,
      ),
      _documentError(AiSkillDocumentErrorCode.missingMetadata),
    );
    expect(
      () => AiSkillMarkdownCodec.decode(
        utf8.encode('''---
schemaVersion: 1
id: incomplete
name: Incomplete
description: Missing output mode
---
Instructions'''),
        sourceFileName: 'SKILL.md',
        importedAt: importedAt,
      ),
      _documentError(AiSkillDocumentErrorCode.missingMetadata),
    );
  });

  test('rejects unknown, malformed, and invalid frontmatter', () {
    expect(
      () => _decodeDocument('''---
schemaVersion: 99
id: test
name: Test
description: Test skill
outputMode: text
---
Instructions''', importedAt),
      _documentError(AiSkillDocumentErrorCode.unsupportedVersion),
    );
    expect(
      () => _decodeDocument('''---
schemaVersion: 1
id: test
name: Test
description: Test skill
outputMode: text
script: dangerous.sh
---
Instructions''', importedAt),
      _documentError(AiSkillDocumentErrorCode.unknownFrontmatterField),
    );
    expect(
      () => _decodeDocument('''---
schemaVersion: [broken
---
Instructions''', importedAt),
      _documentError(AiSkillDocumentErrorCode.malformedFrontmatter),
    );
    expect(
      () => _decodeDocument('''---
schemaVersion: 1
id: test
id: duplicate
name: Test
description: Test skill
outputMode: text
---
Instructions''', importedAt),
      _documentError(AiSkillDocumentErrorCode.malformedFrontmatter),
    );
    expect(
      () => _decodeDocument('''---
schemaVersion: 1
id: test
name: Test
description: Test skill
outputMode: executable
---
Instructions''', importedAt),
      _documentError(AiSkillDocumentErrorCode.invalidMetadata),
    );
    expect(
      () => AiSkillMarkdownCodec.decode(
        utf8.encode(
          List.filled(aiMaxSkillInstructionCharacters + 1, 'x').join(),
        ),
        sourceFileName: 'SKILL.md',
        importedAt: importedAt,
        bodyOnlyId: 'test',
        bodyOnlyName: 'Test',
        bodyOnlyDescription: 'Test skill',
      ),
      _documentError(AiSkillDocumentErrorCode.invalidInstructions),
    );
  });

  test('rejects path-like filenames, excessive bytes, and malformed UTF-8', () {
    expect(
      () => AiSkillMarkdownCodec.decode(
        utf8.encode('Instructions'),
        sourceFileName: '../SKILL.md',
        importedAt: importedAt,
        bodyOnlyId: 'test',
        bodyOnlyName: 'Test',
        bodyOnlyDescription: 'Test skill',
      ),
      _documentError(AiSkillDocumentErrorCode.invalidFileName),
    );
    expect(
      () => AiSkillMarkdownCodec.decode(
        List.filled(aiMaxSkillDocumentBytes + 1, 0x61),
        sourceFileName: 'SKILL.md',
        importedAt: importedAt,
      ),
      _documentError(AiSkillDocumentErrorCode.documentTooLarge),
    );
    expect(
      () => AiSkillMarkdownCodec.decode(
        const [0xc3, 0x28],
        sourceFileName: 'SKILL.md',
        importedAt: importedAt,
      ),
      _documentError(AiSkillDocumentErrorCode.invalidUtf8),
    );
  });
}

AiSkill _decodeDocument(String source, DateTime importedAt) =>
    AiSkillMarkdownCodec.decode(
      utf8.encode(source),
      sourceFileName: 'SKILL.md',
      importedAt: importedAt,
    );

Matcher _documentError(AiSkillDocumentErrorCode code) => throwsA(
  isA<AiSkillDocumentException>().having((error) => error.code, 'code', code),
);

AiSkill _skill({required String instructions}) => AiSkill(
  id: 'suomen-kieli',
  name: 'Suomen kieli',
  description: 'Suomenkielisen tekstin tuottaminen ja tarkistaminen.',
  instructions: instructions,
  createdAt: DateTime.utc(2026, 9, 4),
  updatedAt: DateTime.utc(2026, 9, 4),
);
