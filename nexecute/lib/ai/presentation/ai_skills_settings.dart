import 'package:nexecute/ai/repositories/ai_connection_profile_store.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexecute/ai/application/ai_skill_transfer_service.dart';
import 'package:nexecute/ai/domain/ai_skill.dart';
import 'package:nexecute/ai/infrastructure/ai_skill_markdown_codec.dart';
import 'package:nexecute/ai/presentation/ai_skill_file_gateway.dart';
import 'package:nexecute/ai/presentation/ai_skills_controller.dart';
import 'package:nexecute/ai/repositories/ai_skill_preferences_store.dart';
import 'package:nexecute/ai/repositories/ai_skill_store.dart';
import 'package:provider/provider.dart';

class AiSkillsSettings extends StatefulWidget {
  const AiSkillsSettings({super.key});

  @override
  State<AiSkillsSettings> createState() => _AiSkillsSettingsState();
}

class _AiSkillsSettingsState extends State<AiSkillsSettings> {
  AiSkillsController? _controller;
  AiSkillStore? _store;
  AiSkillTransferService? _transferService;
  AiSkillFileGateway? _fileGateway;
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null || _store != null) return;
    _store = context.read<AiSkillStore?>();
    _transferService = context.read<AiSkillTransferService?>();
    _fileGateway = context.read<AiSkillFileGateway?>();
    final store = _store;
    if (store == null) return;
    final controller = AiSkillsController(
      store: store,
      preferencesStore: context.read<AiSkillPreferencesStore?>(),
      profileStore: context.read<AiConnectionProfileStore?>(),
    );
    controller.addListener(_onChanged);
    _controller = controller;
    unawaited(controller.initialize());
  }

  @override
  void dispose() {
    _controller?.removeListener(_onChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return Column(
      key: const Key('ai-skills-settings'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Skills',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Icon(
              Icons.psychology_alt_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Reusable local instructions for ordinary AI conversations. Skills '
          'cannot grant data access, enable tools, or override Nexecute safety.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Do not put passwords, API keys, credentials, or other secrets in a skill.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(height: 16),
        if (!controller.isAvailable)
          const _SkillStorageUnavailable()
        else if (controller.isLoading)
          const LinearProgressIndicator(key: Key('ai-skills-loading'))
        else ...[
          if (controller.loadError case final error?)
            _SkillLoadFailure(error: error, onRetry: controller.initialize),
          Row(
            children: [
              FilledButton.tonalIcon(
                key: const Key('ai-skill-create'),
                onPressed: () => _editSkill(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create skill'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const Key('ai-skill-import'),
                onPressed:
                    _fileGateway == null ? null : () => unawaited(_import()),
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('Import SKILL.md'),
              ),
            ],
          ),
          if (controller.skills.isNotEmpty) ...[
            const SizedBox(height: 12),
            TextField(
              key: const Key('ai-skill-search'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search skills',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ],
          const SizedBox(height: 12),
          if (controller.skills.isEmpty)
            const _EmptySkillsCard()
          else if (_filteredSkills(controller).isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No skills match this search.'),
            )
          else
            for (final skill in _filteredSkills(controller)) ...[
              _SkillCard(
                skill: skill,
                isDefault: controller.isDefault(skill),
                defaultsAvailable:
                    context.read<AiSkillPreferencesStore?>() != null,
                onEnabledChanged:
                    (value) => _runAction(
                      () => controller.setEnabled(skill, value),
                      success: value ? 'Skill enabled.' : 'Skill disabled.',
                    ),
                onDefaultChanged:
                    (value) => _runAction(
                      () => controller.setDefault(skill, value),
                      success:
                          value
                              ? 'Skill will be active in new conversations.'
                              : 'Skill removed from conversation defaults.',
                    ),
                onAction: (action) => _skillAction(skill, action),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ],
    );
  }

  List<AiSkillMetadata> _filteredSkills(AiSkillsController controller) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return controller.skills;
    return controller.skills
        .where(
          (skill) =>
              skill.id.toLowerCase().contains(query) ||
              skill.name.toLowerCase().contains(query) ||
              skill.description.toLowerCase().contains(query),
        )
        .toList();
  }

  Future<void> _skillAction(
    AiSkillMetadata metadata,
    _SkillAction action,
  ) async {
    switch (action) {
      case _SkillAction.inspect:
        await _editSkill(metadata: metadata, readOnly: true);
      case _SkillAction.edit:
        await _editSkill(metadata: metadata);
      case _SkillAction.duplicate:
        await _duplicate(metadata);
      case _SkillAction.export:
        await _export(metadata);
      case _SkillAction.delete:
        await _delete(metadata);
    }
  }

  Future<void> _editSkill({
    AiSkillMetadata? metadata,
    AiSkill? initial,
    bool readOnly = false,
  }) async {
    final controller = _controller;
    if (controller == null) return;
    AiSkill? original;
    try {
      original =
          metadata == null ? null : await controller.getSkill(metadata.id);
      if (metadata != null && original == null) {
        throw const AiSkillStoreException(
          AiSkillStoreErrorCode.notFound,
          'The skill is no longer available.',
        );
      }
    } catch (error) {
      _showError(error);
      return;
    }
    if (!mounted) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: readOnly,
      builder:
          (context) => _SkillEditorDialog(
            controller: controller,
            original: original,
            initial: initial,
            readOnly: readOnly,
          ),
    );
  }

  Future<void> _duplicate(AiSkillMetadata metadata) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final source = await controller.getSkill(metadata.id);
      if (source == null) {
        throw const AiSkillStoreException(
          AiSkillStoreErrorCode.notFound,
          'The skill is no longer available.',
        );
      }
      final now = DateTime.now();
      final id = _duplicateId(source.id, controller.skills);
      final duplicate = AiSkill(
        id: id,
        name: _boundedCopyName(source.name),
        description: source.description,
        instructions: source.instructions,
        category: source.category,
        capabilities: source.capabilities,
        isEnabled: source.isEnabled,
        createdAt: now,
        updatedAt: now,
      );
      if (mounted) await _editSkill(initial: duplicate);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _import() async {
    final gateway = _fileGateway;
    final controller = _controller;
    if (gateway == null || controller == null) return;
    try {
      final picked = await gateway.pickSkillDocument();
      if (picked == null || !mounted) return;
      AiSkill candidate;
      try {
        candidate = AiSkillMarkdownCodec.decode(
          picked.bytes,
          sourceFileName: picked.fileName,
          importedAt: DateTime.now(),
        );
      } on AiSkillDocumentException catch (error) {
        if (error.code != AiSkillDocumentErrorCode.missingMetadata) rethrow;
        final metadata = await showDialog<_BodyOnlyMetadata>(
          context: context,
          builder: (_) => const _BodyOnlyMetadataDialog(),
        );
        if (metadata == null) return;
        candidate = AiSkillMarkdownCodec.decode(
          picked.bytes,
          sourceFileName: picked.fileName,
          importedAt: DateTime.now(),
          bodyOnlyId: metadata.id,
          bodyOnlyName: metadata.name,
          bodyOnlyDescription: metadata.description,
        );
      }

      try {
        await controller.createSkill(candidate);
      } on AiSkillStoreException catch (error) {
        if (error.code != AiSkillStoreErrorCode.conflict || !mounted) {
          rethrow;
        }
        final existing = await controller.getSkill(candidate.id);
        if (existing == null) rethrow;
        final replace = await _confirmReplace(existing, candidate);
        if (!replace) return;
        final replacement = candidate.copyWith(
          isEnabled: existing.isEnabled,
          createdAt: existing.createdAt,
          updatedAt: _monotonicNow(existing.updatedAt),
        );
        await controller.updateSkill(
          replacement,
          expectedContentHash: existing.contentHash,
        );
      }
      if (mounted) {
        _showSuccess('Skill imported. It is not active automatically.');
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<bool> _confirmReplace(AiSkill existing, AiSkill candidate) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Replace existing skill?'),
                content: Text(
                  '“${existing.name}” already uses the ID ${existing.id}. '
                  'Replace its local instructions with “${candidate.name}”? '
                  'Existing conversations keep the old revision and will show '
                  'a mismatch until explicitly updated.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep existing'),
                  ),
                  FilledButton(
                    key: const Key('ai-skill-confirm-replace'),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Replace'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  Future<void> _export(AiSkillMetadata metadata) async {
    final transfer = _transferService;
    final gateway = _fileGateway;
    if (transfer == null || gateway == null) {
      _showError('File export is unavailable on this platform.');
      return;
    }
    try {
      final exported = await transfer.exportSkill(metadata.id);
      final saved = await gateway.exportSkillDocument(
        fileName: exported.fileName,
        bytes: exported.bytes,
      );
      if (saved && mounted) _showSuccess('SKILL.md exported.');
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(AiSkillMetadata metadata) async {
    final controller = _controller;
    if (controller == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete skill?'),
            content: Text(
              'Delete “${metadata.name}” from this device? Conversations that '
              'reference it will show the skill as unavailable.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('ai-skill-confirm-delete'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    await _runAction(
      () => controller.deleteSkill(metadata),
      success: 'Skill deleted from this device.',
    );
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String success,
  }) async {
    try {
      await action();
      if (mounted) _showSuccess(success);
    } catch (error) {
      _showError(error);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Skill action failed: $error')));
  }
}

enum _SkillAction { inspect, edit, duplicate, export, delete }

class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.skill,
    required this.isDefault,
    required this.defaultsAvailable,
    required this.onEnabledChanged,
    required this.onDefaultChanged,
    required this.onAction,
  });

  final AiSkillMetadata skill;
  final bool isDefault;
  final bool defaultsAvailable;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<bool> onDefaultChanged;
  final ValueChanged<_SkillAction> onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('ai-skill-${skill.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              skill.isEnabled
                  ? Icons.psychology_alt_rounded
                  : Icons.pause_circle_outline_rounded,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skill.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(skill.description),
                  const SizedBox(height: 6),
                  Text(
                    '${skill.id} · '
                    '${skill.isEnabled ? (isDefault ? 'active by default' : 'enabled, inactive') : 'disabled'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Tooltip(
              message:
                  isDefault
                      ? 'Remove from new-conversation defaults'
                      : 'Use in new conversations by default',
              child: IconButton(
                key: ValueKey('ai-skill-default-${skill.id}'),
                onPressed:
                    defaultsAvailable && skill.isEnabled
                        ? () => onDefaultChanged(!isDefault)
                        : null,
                icon: Icon(
                  isDefault ? Icons.star_rounded : Icons.star_border_rounded,
                ),
              ),
            ),
            Switch(
              key: ValueKey('ai-skill-enabled-${skill.id}'),
              value: skill.isEnabled,
              onChanged: onEnabledChanged,
            ),
            PopupMenuButton<_SkillAction>(
              tooltip: 'Skill actions',
              onSelected: onAction,
              itemBuilder:
                  (_) => const [
                    PopupMenuItem(
                      value: _SkillAction.inspect,
                      child: Text('Inspect'),
                    ),
                    PopupMenuItem(
                      value: _SkillAction.edit,
                      child: Text('Edit'),
                    ),
                    PopupMenuItem(
                      value: _SkillAction.duplicate,
                      child: Text('Duplicate'),
                    ),
                    PopupMenuItem(
                      value: _SkillAction.export,
                      child: Text('Export SKILL.md'),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: _SkillAction.delete,
                      child: Text('Delete'),
                    ),
                  ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillEditorDialog extends StatefulWidget {
  const _SkillEditorDialog({
    required this.controller,
    this.original,
    this.initial,
    this.readOnly = false,
  });

  final AiSkillsController controller;
  final AiSkill? original;
  final AiSkill? initial;
  final bool readOnly;

  @override
  State<_SkillEditorDialog> createState() => _SkillEditorDialogState();
}

class _SkillEditorDialogState extends State<_SkillEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _id;
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _instructions;
  late bool _enabled;
  AiSkillCategory? _category;
  Set<String> _capabilities = {};
  bool _saving = false;
  String? _error;

  AiSkill? get _source => widget.original ?? widget.initial;

  @override
  void initState() {
    super.initState();
    final source = _source;
    _id = TextEditingController(text: source?.id ?? '');
    _name = TextEditingController(text: source?.name ?? '');
    _description = TextEditingController(text: source?.description ?? '');
    _instructions = TextEditingController(text: source?.instructions ?? '');
    _enabled = source?.isEnabled ?? true;
    _category = source?.category;
    _capabilities = {...?source?.capabilities};
  }

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _description.dispose();
    _instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.original != null;
    return AlertDialog(
      title: Text(
        widget.readOnly
            ? 'Inspect skill'
            : editing
            ? 'Edit skill'
            : 'Create skill',
      ),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error case final error?) ...[
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  key: const Key('ai-skill-id-field'),
                  controller: _id,
                  readOnly: widget.readOnly || editing,
                  maxLength: aiMaxSkillIdCharacters,
                  decoration: const InputDecoration(
                    labelText: 'ID',
                    helperText:
                        'Lowercase words separated by hyphens; cannot change after creation.',
                  ),
                  validator:
                      (value) =>
                          isValidAiSkillId(value ?? '')
                              ? null
                              : 'Enter a valid skill ID.',
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('ai-skill-name-field'),
                  controller: _name,
                  readOnly: widget.readOnly,
                  maxLength: aiMaxSkillNameCharacters,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator:
                      (value) => _singleLineError(
                        value,
                        'name',
                        aiMaxSkillNameCharacters,
                      ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const Key('ai-skill-description-field'),
                  controller: _description,
                  readOnly: widget.readOnly,
                  maxLength: aiMaxSkillDescriptionCharacters,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator:
                      (value) => _singleLineError(
                        value,
                        'description',
                        aiMaxSkillDescriptionCharacters,
                      ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Optional read capabilities. These declarations never authorize access; each request still needs your approval.',
                ),
                for (final capability in aiSkillCapabilityIds)
                  CheckboxListTile(
                    title: Text(capability),
                    value: _capabilities.contains(capability),
                    onChanged:
                        (value) => setState(() {
                          if (value == true) {
                            _capabilities.add(capability);
                          } else {
                            _capabilities.remove(capability);
                          }
                        }),
                  ),
                DropdownButtonFormField<AiSkillCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category (optional)',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    for (final c in AiSkillCategory.values)
                      DropdownMenuItem(value: c, child: Text(c.name)),
                  ],
                  onChanged: (value) => setState(() => _category = value),
                ),
                TextFormField(
                  key: const Key('ai-skill-instructions-field'),
                  controller: _instructions,
                  readOnly: widget.readOnly,
                  minLines: 10,
                  maxLines: 18,
                  maxLength: aiMaxSkillInstructionCharacters,
                  decoration: const InputDecoration(
                    labelText: 'Instructions (Markdown)',
                    alignLabelWithHint: true,
                  ),
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter skill instructions.'
                              : null,
                ),
                const SizedBox(height: 8),
                Text(
                  'Never include passwords, API keys, credentials, or secrets. '
                  'Skills are sent to the selected AI provider when active.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                if (!widget.readOnly)
                  SwitchListTile(
                    key: const Key('ai-skill-editor-enabled'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enabled'),
                    subtitle: const Text(
                      'Enabled skills remain inactive until explicitly selected.',
                    ),
                    value: _enabled,
                    onChanged: (value) => setState(() => _enabled = value),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(widget.readOnly ? 'Close' : 'Cancel'),
        ),
        if (!widget.readOnly)
          FilledButton(
            key: const Key('ai-skill-save'),
            onPressed: _saving ? null : _save,
            child:
                _saving
                    ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Save'),
          ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final original = widget.original;
      final now = DateTime.now();
      final skill = AiSkill(
        id: _id.text,
        name: _name.text,
        description: _description.text,
        instructions: _instructions.text,
        category: _category,
        capabilities: _capabilities,
        isEnabled: _enabled,
        createdAt: original?.createdAt ?? widget.initial?.createdAt ?? now,
        updatedAt: original == null ? now : _monotonicNow(original.updatedAt),
      );
      if (original == null) {
        await widget.controller.createSkill(skill);
      } else {
        await widget.controller.updateSkill(
          skill,
          expectedContentHash: original.contentHash,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _BodyOnlyMetadata {
  const _BodyOnlyMetadata({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;
}

class _BodyOnlyMetadataDialog extends StatefulWidget {
  const _BodyOnlyMetadataDialog();

  @override
  State<_BodyOnlyMetadataDialog> createState() =>
      _BodyOnlyMetadataDialogState();
}

class _BodyOnlyMetadataDialogState extends State<_BodyOnlyMetadataDialog> {
  final _formKey = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _name = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Describe this body-only skill'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'The Markdown instruction body will be imported unchanged.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('ai-skill-import-id'),
                controller: _id,
                maxLength: aiMaxSkillIdCharacters,
                decoration: const InputDecoration(labelText: 'ID'),
                validator:
                    (value) =>
                        isValidAiSkillId(value ?? '')
                            ? null
                            : 'Enter a valid skill ID.',
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('ai-skill-import-name'),
                controller: _name,
                maxLength: aiMaxSkillNameCharacters,
                decoration: const InputDecoration(labelText: 'Name'),
                validator:
                    (value) => _singleLineError(
                      value,
                      'name',
                      aiMaxSkillNameCharacters,
                    ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('ai-skill-import-description'),
                controller: _description,
                maxLength: aiMaxSkillDescriptionCharacters,
                decoration: const InputDecoration(labelText: 'Description'),
                validator:
                    (value) => _singleLineError(
                      value,
                      'description',
                      aiMaxSkillDescriptionCharacters,
                    ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('ai-skill-import-metadata-save'),
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              _BodyOnlyMetadata(
                id: _id.text,
                name: _name.text,
                description: _description.text,
              ),
            );
          },
          child: const Text('Import'),
        ),
      ],
    );
  }
}

class _SkillStorageUnavailable extends StatelessWidget {
  const _SkillStorageUnavailable();

  @override
  Widget build(BuildContext context) => const Card(
    key: Key('ai-skills-unavailable'),
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'Skill storage is unavailable. Ordinary AI chat remains available without skills.',
      ),
    ),
  );
}

class _SkillLoadFailure extends StatelessWidget {
  const _SkillLoadFailure({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: ListTile(
      title: const Text('Could not load local skills'),
      subtitle: Text(error.toString()),
      trailing: IconButton(
        tooltip: 'Retry loading skills',
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ),
  );
}

class _EmptySkillsCard extends StatelessWidget {
  const _EmptySkillsCard();

  @override
  Widget build(BuildContext context) => const Card(
    key: Key('ai-skills-empty'),
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'No skills yet. Create one here or import a UTF-8 SKILL.md file.',
      ),
    ),
  );
}

String? _singleLineError(String? value, String label, int maximumCharacters) {
  if (value == null ||
      value.isEmpty ||
      value.trim() != value ||
      value.contains('\n') ||
      value.runes.length > maximumCharacters ||
      value.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f)) {
    return 'Enter a trimmed, single-line $label of at most '
        '$maximumCharacters characters.';
  }
  return null;
}

String _duplicateId(String id, List<AiSkillMetadata> skills) {
  final ids = skills.map((skill) => skill.id).toSet();
  for (var suffix = 1; suffix < 10000; suffix++) {
    final ending = suffix == 1 ? '-copy' : '-copy-$suffix';
    final prefixLength = aiMaxSkillIdCharacters - ending.length;
    final prefix = id.substring(0, id.length.clamp(0, prefixLength));
    final candidate = '$prefix$ending';
    if (!ids.contains(candidate)) return candidate;
  }
  throw StateError('Could not create a unique duplicate skill ID.');
}

String _boundedCopyName(String name) {
  const ending = ' copy';
  final maximumPrefix = aiMaxSkillNameCharacters - ending.length;
  return '${name.substring(0, name.length.clamp(0, maximumPrefix))}$ending';
}

DateTime _monotonicNow(DateTime previous) {
  final now = DateTime.now();
  return now.isAfter(previous)
      ? now
      : previous.add(const Duration(microseconds: 1));
}
