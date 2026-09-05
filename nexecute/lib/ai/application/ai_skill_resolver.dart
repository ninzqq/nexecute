import 'package:nexecute/ai/domain/ai_skill_invocation.dart';
import 'package:nexecute/ai/repositories/ai_skill_store.dart';

enum AiSkillResolutionIssueKind {
  missing,
  changed,
  disabled,
  storageUnavailable,
  promptBudgetUnavailable,
}

final class AiSkillResolutionIssue {
  const AiSkillResolutionIssue({
    required this.reference,
    required this.kind,
    this.availableContentHash,
  });

  final AiSkillReference reference;
  final AiSkillResolutionIssueKind kind;

  /// Present for a changed local skill so the interface can offer an explicit
  /// replacement. No instruction body is included in recovery diagnostics.
  final String? availableContentHash;
}

final class AiSkillResolutionException implements Exception {
  AiSkillResolutionException(Iterable<AiSkillResolutionIssue> issues)
    : issues = List.unmodifiable(issues) {
    if (this.issues.isEmpty) {
      throw ArgumentError.value(issues, 'issues', 'must not be empty');
    }
  }

  final List<AiSkillResolutionIssue> issues;

  @override
  String toString() =>
      'One or more active skills require explicit recovery before sending.';
}

/// Resolves pinned conversation references into exact, local skill revisions.
final class AiSkillResolver {
  const AiSkillResolver({required AiSkillStore store}) : _store = store;

  final AiSkillStore _store;

  Future<List<AiResolvedSkillInvocation>> resolve(
    Iterable<AiSkillReference> references,
  ) async {
    final normalized = normalizeAiSkillReferences(references);
    if (normalized.isEmpty) return const [];
    if (!_store.isAvailable) {
      throw AiSkillResolutionException([
        for (final reference in normalized)
          AiSkillResolutionIssue(
            reference: reference,
            kind: AiSkillResolutionIssueKind.storageUnavailable,
          ),
      ]);
    }

    final resolved = <AiResolvedSkillInvocation>[];
    final issues = <AiSkillResolutionIssue>[];
    for (final reference in normalized) {
      try {
        final skill = await _store.getSkill(reference.id);
        if (skill == null) {
          issues.add(
            AiSkillResolutionIssue(
              reference: reference,
              kind: AiSkillResolutionIssueKind.missing,
            ),
          );
        } else if (!skill.isEnabled) {
          issues.add(
            AiSkillResolutionIssue(
              reference: reference,
              kind: AiSkillResolutionIssueKind.disabled,
              availableContentHash: skill.contentHash,
            ),
          );
        } else if (skill.contentHash != reference.contentHash) {
          issues.add(
            AiSkillResolutionIssue(
              reference: reference,
              kind: AiSkillResolutionIssueKind.changed,
              availableContentHash: skill.contentHash,
            ),
          );
        } else {
          resolved.add(AiResolvedSkillInvocation.fromSkill(skill));
        }
      } on AiSkillStoreException {
        issues.add(
          AiSkillResolutionIssue(
            reference: reference,
            kind: AiSkillResolutionIssueKind.storageUnavailable,
          ),
        );
      }
    }
    if (issues.isNotEmpty) throw AiSkillResolutionException(issues);
    return List.unmodifiable(resolved);
  }
}
