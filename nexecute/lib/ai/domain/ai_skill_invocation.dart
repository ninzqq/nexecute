import 'package:nexecute/ai/domain/ai_skill.dart';

/// The minimal, portable pointer persisted with a conversation.
///
/// Instruction bodies remain in the local skill store. The content hash pins
/// the exact revision so another device cannot silently substitute different
/// instructions for the same skill ID.
final class AiSkillReference {
  factory AiSkillReference({required String id, required String contentHash}) {
    if (!isValidAiSkillId(id)) {
      throw ArgumentError.value(id, 'id', 'must be a valid skill ID');
    }
    if (!isValidAiSkillContentHash(contentHash)) {
      throw ArgumentError.value(
        contentHash,
        'contentHash',
        'must be a lowercase SHA-256 digest',
      );
    }
    return AiSkillReference._(id: id, contentHash: contentHash);
  }

  factory AiSkillReference.fromSkill(AiSkill skill) =>
      AiSkillReference(id: skill.id, contentHash: skill.contentHash);

  const AiSkillReference._({required this.id, required this.contentHash});

  final String id;
  final String contentHash;

  @override
  bool operator ==(Object other) =>
      other is AiSkillReference &&
      other.id == id &&
      other.contentHash == contentHash;

  @override
  int get hashCode => Object.hash(id, contentHash);
}

/// An immutable, validated skill snapshot attached to one provider request.
///
/// Only the prompt composer consumes [instructions]. Provider adapters receive
/// the resulting composed system instruction and must not reinterpret this
/// object as a tool, schema, or authorization grant.
final class AiResolvedSkillInvocation {
  factory AiResolvedSkillInvocation.fromSkill(AiSkill skill) =>
      AiResolvedSkillInvocation._(
        id: skill.id,
        displayName: skill.name,
        contentHash: skill.contentHash,
        instructions: skill.instructions,
        category: skill.category,
      );

  const AiResolvedSkillInvocation._({
    required this.id,
    required this.displayName,
    required this.contentHash,
    required this.instructions,
    required this.category,
  });

  final String id;
  final String displayName;
  final String contentHash;
  final String instructions;
  final AiSkillCategory? category;

  AiSkillReference get reference =>
      AiSkillReference(id: id, contentHash: contentHash);
}

List<AiSkillReference> normalizeAiSkillReferences(
  Iterable<AiSkillReference> references,
) {
  final byId = <String, AiSkillReference>{};
  for (final reference in references) {
    if (byId.containsKey(reference.id)) {
      throw ArgumentError.value(
        references,
        'references',
        'must not contain duplicate skill IDs',
      );
    }
    byId[reference.id] = reference;
  }
  final result =
      byId.values.toList()..sort((left, right) => left.id.compareTo(right.id));
  return List.unmodifiable(result);
}
