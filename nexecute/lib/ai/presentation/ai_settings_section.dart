import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/ai/domain/ai_connection_result.dart';
import 'package:nexecute/ai/domain/ai_model_info.dart';
import 'package:nexecute/ai/domain/ai_protocol.dart';
import 'package:nexecute/ai/presentation/ai_endpoint_validation.dart';
import 'package:nexecute/ai/presentation/ai_settings_controller.dart';
import 'package:nexecute/ai/repositories/ai_assistant_repository.dart';
import 'package:nexecute/ai/repositories/ai_connection_profile_store.dart';
import 'package:provider/provider.dart';

class AiSettingsSection extends StatefulWidget {
  const AiSettingsSection({super.key});

  @override
  State<AiSettingsSection> createState() => _AiSettingsSectionState();
}

class _AiSettingsSectionState extends State<AiSettingsSection> {
  AiSettingsController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;

    final controller = AiSettingsController(
      profileStore: context.read<AiConnectionProfileStore>(),
      assistantRepository: context.read<AiAssistantRepository>(),
    );
    controller.addListener(_onControllerChanged);
    _controller = controller;
    unawaited(controller.initialize());
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();

    return Column(
      key: const Key('ai-settings-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'AI assistant',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Icon(
              Icons.auto_awesome_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Configure local model servers and private AI gateways. AI remains optional and never blocks the rest of Nexecute.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        if (controller.isLoading)
          const LinearProgressIndicator(key: Key('ai-profiles-loading'))
        else if (controller.loadError case final error?)
          _LoadFailure(error: error, onRetry: controller.initialize)
        else ...[
          if (controller.profiles.isEmpty)
            const _EmptyProfilesCard()
          else
            for (final profile in controller.profiles) ...[
              _ProfileCard(
                profile: profile,
                selected: controller.activeProfile?.id == profile.id,
                testing: controller.testingProfileId == profile.id,
                connectionResult:
                    controller.testedProfileId == profile.id
                        ? controller.connectionResult
                        : null,
                onSelect: () => controller.selectProfile(profile.id),
                onTest: () => controller.testConnection(profile),
                onEdit: () => _editProfile(profile),
                onDuplicate: () => controller.duplicateProfile(profile),
                onDelete: () => _deleteProfile(profile),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              key: const Key('ai-add-profile'),
              onPressed: () => _editProfile(null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add AI connection'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _editProfile(AiConnectionProfile? profile) async {
    final controller = _controller;
    if (controller == null) return;

    final savedProfile = await showDialog<AiConnectionProfile>(
      context: context,
      builder:
          (context) => _AiConnectionProfileEditor(
            profile: profile,
            settingsController: controller,
          ),
    );
    if (savedProfile == null || !mounted) return;

    try {
      await controller.saveProfile(savedProfile);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save AI connection: $error')),
      );
    }
  }

  Future<void> _deleteProfile(AiConnectionProfile profile) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete AI connection?'),
            content: Text(
              'Delete “${profile.name}”? Existing conversations are not deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (shouldDelete != true || !mounted) return;
    await _controller?.deleteProfile(profile.id);
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Could not load AI connections',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(error.toString()),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProfilesCard extends StatelessWidget {
  const _EmptyProfilesCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No AI connection is configured. Calendar, Tasks, and Notes continue to work normally.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ProfileAction { edit, duplicate, delete }

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.selected,
    required this.testing,
    required this.connectionResult,
    required this.onSelect,
    required this.onTest,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  final AiConnectionProfile profile;
  final bool selected;
  final bool testing;
  final AiConnectionResult? connectionResult;
  final Future<void> Function() onSelect;
  final Future<AiConnectionResult> Function() onTest;
  final Future<void> Function() onEdit;
  final Future<AiConnectionProfile> Function() onDuplicate;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      key: Key('ai-profile-${profile.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: selected ? null : onSelect,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color:
                          selected ? colorScheme.primary : colorScheme.outline,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                profile.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (selected) ...[
                              const SizedBox(width: 8),
                              const _ActiveBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${profile.protocol.label} · ${profile.modelId}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile.baseUrl.toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${profile.reasoningEffort.label} reasoning · '
                          '${profile.maxOutputTokens} max tokens',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<_ProfileAction>(
                    tooltip: 'AI connection actions',
                    onSelected: (action) {
                      switch (action) {
                        case _ProfileAction.edit:
                          unawaited(onEdit());
                        case _ProfileAction.duplicate:
                          unawaited(onDuplicate());
                        case _ProfileAction.delete:
                          unawaited(onDelete());
                      }
                    },
                    itemBuilder:
                        (context) => const [
                          PopupMenuItem(
                            value: _ProfileAction.edit,
                            child: Text('Edit'),
                          ),
                          PopupMenuItem(
                            value: _ProfileAction.duplicate,
                            child: Text('Duplicate'),
                          ),
                          PopupMenuItem(
                            value: _ProfileAction.delete,
                            child: Text('Delete'),
                          ),
                        ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    key: Key('ai-profile-test-${profile.id}'),
                    onPressed: testing ? null : onTest,
                    icon:
                        testing
                            ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.network_check_rounded),
                    label: Text(testing ? 'Testing…' : 'Test connection'),
                  ),
                  if (!selected) ...[
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: onSelect,
                      child: const Text('Use this connection'),
                    ),
                  ],
                ],
              ),
              if (connectionResult case final result?) ...[
                const SizedBox(height: 4),
                _ConnectionResultLine(result: result),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Active',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ConnectionResultLine extends StatelessWidget {
  const _ConnectionResultLine({required this.result});

  final AiConnectionResult result;

  @override
  Widget build(BuildContext context) {
    final successful = result.isConnected;
    final color =
        successful
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            successful ? Icons.check_circle_outline : Icons.error_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiConnectionProfileEditor extends StatefulWidget {
  const _AiConnectionProfileEditor({
    required this.profile,
    required this.settingsController,
  });

  final AiConnectionProfile? profile;
  final AiSettingsController settingsController;

  @override
  State<_AiConnectionProfileEditor> createState() =>
      _AiConnectionProfileEditorState();
}

class _AiConnectionProfileEditorState
    extends State<_AiConnectionProfileEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelController;
  late final TextEditingController _maxOutputTokensController;
  late final TextEditingController _connectionTimeoutController;
  late final TextEditingController _responseIdleTimeoutController;
  late final String _profileId;
  late AiProtocol _protocol;
  late AiAuthenticationMode _authenticationMode;
  late AiReasoningEffort _reasoningEffort;
  List<AiModelInfo> _models = const [];
  bool _discoveringModels = false;
  String? _discoveryMessage;
  String? _urlWarning;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _profileId = profile?.id ?? widget.settingsController.createProfileId();
    _nameController = TextEditingController(text: profile?.name ?? '');
    _baseUrlController = TextEditingController(
      text: profile?.baseUrl.toString() ?? '',
    );
    _modelController = TextEditingController(text: profile?.modelId ?? '');
    _maxOutputTokensController = TextEditingController(
      text: (profile?.maxOutputTokens ?? aiDefaultMaxOutputTokens).toString(),
    );
    _connectionTimeoutController = TextEditingController(
      text:
          (profile?.connectionTimeout ?? aiDefaultConnectionTimeout).inSeconds
              .toString(),
    );
    _responseIdleTimeoutController = TextEditingController(
      text:
          (profile?.responseIdleTimeout ?? aiDefaultResponseIdleTimeout)
              .inSeconds
              .toString(),
    );
    _protocol = profile?.protocol ?? AiProtocol.openAiCompatibleChat;
    _authenticationMode =
        profile?.authenticationMode ?? AiAuthenticationMode.none;
    _reasoningEffort = profile?.reasoningEffort ?? AiReasoningEffort.automatic;
    _updateUrlWarning();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    _maxOutputTokensController.dispose();
    _connectionTimeoutController.dispose();
    _responseIdleTimeoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.profile != null;
    return AlertDialog(
      title: Text(editing ? 'Edit AI connection' : 'Add AI connection'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  key: const Key('ai-profile-name-field'),
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Connection name',
                    hintText: 'Home Ollama',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter a connection name.'
                              : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<AiProtocol>(
                  key: const Key('ai-profile-protocol-field'),
                  initialValue: _protocol,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Protocol'),
                  items: [
                    for (final protocol in AiProtocol.values)
                      DropdownMenuItem(
                        value: protocol,
                        child: Text(
                          protocol.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _protocol = value;
                      _models = const [];
                      _discoveryMessage = null;
                    });
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('ai-profile-url-field'),
                  controller: _baseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://ai-pc.example.ts.net/v1',
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  onChanged: (_) => setState(_updateUrlWarning),
                  validator:
                      (value) =>
                          validateAiEndpointUrl(
                            value ?? '',
                            isWeb: kIsWeb,
                          ).error,
                ),
                if (_urlWarning case final warning?) ...[
                  const SizedBox(height: 8),
                  _InlineWarning(message: warning),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('ai-profile-model-field'),
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: 'Model ID',
                    hintText: 'qwen3:8b',
                  ),
                  autocorrect: false,
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter or select a model ID.'
                              : null,
                ),
                const SizedBox(height: 8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('ai-discover-models'),
                      onPressed:
                          _discoveringModels ||
                                  !_protocol.defaultCapabilities.contains(
                                    AiCapability.modelDiscovery,
                                  )
                              ? null
                              : _discoverModels,
                      icon:
                          _discoveringModels
                              ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.download_rounded),
                      label: Text(
                        _discoveringModels ? 'Loading…' : 'Load models',
                      ),
                    ),
                    if (_models.isNotEmpty)
                      DropdownButton<String>(
                        key: const Key('ai-discovered-models'),
                        hint: const Text('Choose available model'),
                        value:
                            _models.any(
                                  (model) => model.id == _modelController.text,
                                )
                                ? _modelController.text
                                : null,
                        items: [
                          for (final model in _models)
                            DropdownMenuItem(
                              value: model.id,
                              child: Text(model.displayName ?? model.id),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _modelController.text = value);
                        },
                      ),
                  ],
                ),
                if (_discoveryMessage case final message?) ...[
                  const SizedBox(height: 6),
                  Text(message, style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 14),
                ExpansionTile(
                  key: const Key('ai-generation-controls'),
                  initiallyExpanded: true,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: const Text('Generation controls'),
                  subtitle: const Text('Reasoning, output, and timeouts'),
                  children: [
                    DropdownButtonFormField<AiReasoningEffort>(
                      key: const Key('ai-profile-reasoning-field'),
                      initialValue: _reasoningEffort,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Reasoning effort',
                        helperText:
                            'Automatic keeps the model or server default.',
                      ),
                      items: [
                        for (final effort in AiReasoningEffort.values)
                          DropdownMenuItem(
                            value: effort,
                            child: Text(effort.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _reasoningEffort = value);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('ai-profile-max-output-tokens-field'),
                      controller: _maxOutputTokensController,
                      decoration: const InputDecoration(
                        labelText: 'Maximum output tokens',
                        helperText: 'Limits the length of each model response.',
                      ),
                      keyboardType: TextInputType.number,
                      validator:
                          (value) => _boundedIntegerError(
                            value,
                            label: 'maximum output tokens',
                            minimum: aiMinOutputTokens,
                            maximum: aiMaxOutputTokens,
                          ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('ai-profile-connection-timeout-field'),
                      controller: _connectionTimeoutController,
                      decoration: const InputDecoration(
                        labelText: 'Connection/start timeout (seconds)',
                        helperText:
                            'Includes waiting for a cold model to begin.',
                      ),
                      keyboardType: TextInputType.number,
                      validator:
                          (value) => _boundedIntegerError(
                            value,
                            label: 'connection timeout',
                            minimum: aiMinTimeoutSeconds,
                            maximum: aiMaxTimeoutSeconds,
                          ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('ai-profile-stream-timeout-field'),
                      controller: _responseIdleTimeoutController,
                      decoration: const InputDecoration(
                        labelText: 'Stream idle timeout (seconds)',
                        helperText:
                            'Stops a response that has stopped sending data.',
                      ),
                      keyboardType: TextInputType.number,
                      validator:
                          (value) => _boundedIntegerError(
                            value,
                            label: 'stream idle timeout',
                            minimum: aiMinTimeoutSeconds,
                            maximum: aiMaxTimeoutSeconds,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<AiAuthenticationMode>(
                  key: const Key('ai-profile-auth-field'),
                  initialValue: _authenticationMode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Authentication',
                  ),
                  items: [
                    for (final mode in AiAuthenticationMode.values)
                      DropdownMenuItem(
                        value: mode,
                        enabled:
                            !mode.requiresCredential ||
                            widget.profile?.credentialReference != null,
                        child: Text(
                          mode.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _authenticationMode = value);
                    }
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  'Bearer-token and API-key entry will be enabled only with secure credential storage. Direct hosted-provider credentials remain unavailable on web.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('ai-profile-save'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _updateUrlWarning() {
    _urlWarning =
        validateAiEndpointUrl(_baseUrlController.text, isWeb: kIsWeb).warning;
  }

  Future<void> _discoverModels() async {
    final validation = validateAiEndpointUrl(
      _baseUrlController.text,
      isWeb: kIsWeb,
    );
    if (!validation.isValid) {
      _formKey.currentState?.validate();
      return;
    }

    setState(() {
      _discoveringModels = true;
      _discoveryMessage = null;
    });
    final profile = _buildProfile(
      baseUrl: validation.uri!,
      fallbackModelId: _modelController.text.trim(),
    );
    final models = await widget.settingsController.discoverModels(profile);
    if (!mounted) return;
    setState(() {
      _discoveringModels = false;
      _models = models;
      _discoveryMessage =
          widget.settingsController.modelDiscoveryError != null
              ? 'Could not load models: ${widget.settingsController.modelDiscoveryError}'
              : models.isEmpty
              ? 'No models were reported. You can still enter the model ID manually.'
              : '${models.length} model${models.length == 1 ? '' : 's'} available.';
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final validation = validateAiEndpointUrl(
      _baseUrlController.text,
      isWeb: kIsWeb,
    );
    if (!validation.isValid) return;

    Navigator.pop(
      context,
      _buildProfile(
        baseUrl: validation.uri!,
        fallbackModelId: _modelController.text.trim(),
      ),
    );
  }

  AiConnectionProfile _buildProfile({
    required Uri baseUrl,
    required String fallbackModelId,
  }) {
    return AiConnectionProfile(
      id: _profileId,
      name: _nameController.text.trim(),
      protocol: _protocol,
      baseUrl: baseUrl,
      modelId: fallbackModelId,
      authenticationMode: _authenticationMode,
      credentialReference: widget.profile?.credentialReference,
      reasoningEffort: _reasoningEffort,
      maxOutputTokens: int.parse(_maxOutputTokensController.text.trim()),
      connectionTimeout: Duration(
        seconds: int.parse(_connectionTimeoutController.text.trim()),
      ),
      responseIdleTimeout: Duration(
        seconds: int.parse(_responseIdleTimeoutController.text.trim()),
      ),
      capabilityOverrides: widget.profile?.capabilityOverrides ?? const {},
    );
  }

  static String? _boundedIntegerError(
    String? rawValue, {
    required String label,
    required int minimum,
    required int maximum,
  }) {
    final value = int.tryParse(rawValue?.trim() ?? '');
    if (value == null) return 'Enter $label as a whole number.';
    if (value < minimum || value > maximum) {
      return 'Use a value from $minimum to $maximum.';
    }
    return null;
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.tertiary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

extension on AiProtocol {
  String get label => switch (this) {
    AiProtocol.openAiCompatibleChat => 'OpenAI-compatible chat',
    AiProtocol.openAiResponses => 'OpenAI Responses',
    AiProtocol.anthropicMessages => 'Anthropic Messages',
    AiProtocol.nexecuteGateway => 'Nexecute gateway',
  };
}

extension on AiAuthenticationMode {
  String get label => switch (this) {
    AiAuthenticationMode.none => 'None',
    AiAuthenticationMode.bearerToken => 'Bearer token (not yet available)',
    AiAuthenticationMode.apiKeyHeader => 'API key header (not yet available)',
    AiAuthenticationMode.gatewaySession => 'Nexecute gateway session',
  };
}

extension on AiReasoningEffort {
  String get label => switch (this) {
    AiReasoningEffort.automatic => 'Automatic',
    AiReasoningEffort.none => 'None',
    AiReasoningEffort.low => 'Low',
    AiReasoningEffort.medium => 'Medium',
    AiReasoningEffort.high => 'High',
  };
}
