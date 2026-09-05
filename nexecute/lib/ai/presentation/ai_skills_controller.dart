import 'package:nexecute/ai/application/ai_prompt_composer.dart';
import 'package:nexecute/ai/application/ai_request_budget.dart';
import 'package:nexecute/ai/application/ai_skill_resolver.dart';
import 'package:nexecute/ai/domain/ai_chat_request.dart';
import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/ai/domain/ai_protocol.dart';
import 'package:nexecute/ai/repositories/ai_connection_profile_store.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nexecute/ai/domain/ai_skill.dart';
import 'package:nexecute/ai/domain/ai_skill_invocation.dart';
import 'package:nexecute/ai/repositories/ai_skill_preferences_store.dart';
import 'package:nexecute/ai/repositories/ai_skill_store.dart';

final class AiSkillsController extends ChangeNotifier {
  AiSkillsController({
    required AiSkillStore store,
    AiSkillPreferencesStore? preferencesStore,
    AiConnectionProfileStore? profileStore,
    DateTime Function()? clock,
  }) : _store = store,
       _preferencesStore = preferencesStore,
       _profileStore = profileStore,
       _clock = clock ?? DateTime.now;

  final AiSkillStore _store;
  final AiConnectionProfileStore? _profileStore;
  final AiSkillPreferencesStore? _preferencesStore;
  final DateTime Function() _clock;
  StreamSubscription<List<AiSkillMetadata>>? _skillsSubscription;
  StreamSubscription<List<AiSkillReference>>? _defaultsSubscription;
  bool _disposed = false;

  List<AiSkillMetadata> skills = const [];
  List<AiSkillReference> defaultSkills = const [];
  bool isLoading = true;
  Object? loadError;

  bool get isAvailable => _store.isAvailable;

  bool isDefault(AiSkillMetadata skill) => defaultSkills.any(
    (reference) =>
        reference.id == skill.id && reference.contentHash == skill.contentHash,
  );

  Future<void> initialize() async {
    await _skillsSubscription?.cancel();
    await _defaultsSubscription?.cancel();
    isLoading = true;
    loadError = null;
    _notify();
    if (!_store.isAvailable) {
      isLoading = false;
      loadError = const AiSkillStoreException(
        AiSkillStoreErrorCode.unavailable,
        'Skill storage is unavailable on this platform.',
      );
      _notify();
      return;
    }
    try {
      skills = await _store.getSkills();
      defaultSkills = await _preferencesStore?.getDefaultSkills() ?? const [];
      _skillsSubscription = _store.watchSkills().listen(
        (value) {
          skills = value;
          _notify();
        },
        onError: (Object error) {
          loadError = error;
          _notify();
        },
      );
      _defaultsSubscription = _preferencesStore?.watchDefaultSkills().listen(
        (value) {
          defaultSkills = value;
          _notify();
        },
        onError: (Object error) {
          loadError = error;
          _notify();
        },
      );
    } catch (error) {
      loadError = error;
    } finally {
      isLoading = false;
      _notify();
    }
  }

  Future<AiSkill?> getSkill(String skillId) => _store.getSkill(skillId);

  Future<void> createSkill(AiSkill skill) =>
      _store.saveSkill(skill, mode: AiSkillSaveMode.createOnly);

  Future<void> updateSkill(
    AiSkill skill, {
    required String expectedContentHash,
  }) async {
    await _store.saveSkill(
      skill,
      mode: AiSkillSaveMode.replaceOnly,
      expectedContentHash: expectedContentHash,
    );
    await _replaceDefaultRevisionIfNeeded(skill);
  }

  Future<void> setEnabled(AiSkillMetadata metadata, bool enabled) async {
    final skill = await _store.getSkill(metadata.id);
    if (skill == null) {
      throw AiSkillStoreException(
        AiSkillStoreErrorCode.notFound,
        'Skill not found: ${metadata.id}.',
      );
    }
    final now = _clock();
    final updated = skill.copyWith(
      isEnabled: enabled,
      updatedAt:
          now.isAfter(skill.updatedAt)
              ? now
              : skill.updatedAt.add(const Duration(microseconds: 1)),
    );
    await _store.saveSkill(
      updated,
      mode: AiSkillSaveMode.replaceOnly,
      expectedContentHash: metadata.contentHash,
    );
    if (!enabled) {
      await _removeDefault(metadata.id);
    } else {
      await _replaceDefaultRevisionIfNeeded(updated);
    }
  }

  Future<void> setDefault(AiSkillMetadata metadata, bool enabled) async {
    final preferences = _preferencesStore;
    if (preferences == null) {
      throw StateError('Default skill preferences are unavailable.');
    }
    final profile = await _profileStore?.getActiveProfile();
    final next =
        enabled
            ? [
              if (profile?.allowMultipleSkills == true)
                ...defaultSkills.where((s) => s.id != metadata.id),
              AiSkillReference(
                id: metadata.id,
                contentHash: metadata.contentHash,
              ),
            ]
            : [
              for (final reference in defaultSkills)
                if (reference.id != metadata.id) reference,
            ];
    if (enabled && !metadata.isEnabled) {
      throw StateError('Enable the skill before making it active by default.');
    }
    if (enabled) {
      final resolved = await AiSkillResolver(store: _store).resolve(next);
      final budgetProfile =
          profile ??
          AiConnectionProfile(
            id: 'fallback',
            name: 'Fallback',
            protocol: AiProtocol.openAiCompatibleChat,
            baseUrl: Uri.parse('http://localhost'),
            modelId: 'unconfigured',
          );
      AiRequestBudget.validate(
        AiChatRequest(
          connectionProfile: budgetProfile,
          conversationId: 'defaults',
          messages: const [],
          resolvedSkills: resolved,
          systemInstruction: const AiPromptComposer().compose(
            profilePreferences: budgetProfile.systemPrompt,
            resolvedSkills: resolved,
          ),
        ),
      );
    }
    await preferences.setDefaultSkills(next);
    defaultSkills = normalizeAiSkillReferences(next);
    _notify();
  }

  Future<void> deleteSkill(AiSkillMetadata metadata) async {
    await _store.deleteSkill(
      metadata.id,
      expectedContentHash: metadata.contentHash,
    );
    await _removeDefault(metadata.id);
  }

  Future<void> _replaceDefaultRevisionIfNeeded(AiSkill skill) async {
    final preferences = _preferencesStore;
    if (preferences == null ||
        !defaultSkills.any((reference) => reference.id == skill.id)) {
      return;
    }
    final next = [
      for (final reference in defaultSkills)
        if (reference.id == skill.id)
          AiSkillReference.fromSkill(skill)
        else
          reference,
    ];
    await preferences.setDefaultSkills(next);
    defaultSkills = normalizeAiSkillReferences(next);
    _notify();
  }

  Future<void> _removeDefault(String skillId) async {
    final preferences = _preferencesStore;
    if (preferences == null ||
        !defaultSkills.any((reference) => reference.id == skillId)) {
      return;
    }
    final next = defaultSkills.where((reference) => reference.id != skillId);
    await preferences.setDefaultSkills(next);
    defaultSkills = normalizeAiSkillReferences(next);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_skillsSubscription?.cancel());
    unawaited(_defaultsSubscription?.cancel());
    super.dispose();
  }
}
