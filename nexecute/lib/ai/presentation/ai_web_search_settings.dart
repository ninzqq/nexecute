import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nexecute/ai/domain/ai_web_search.dart';
import 'package:nexecute/ai/presentation/ai_web_search_settings_controller.dart';
import 'package:nexecute/ai/repositories/ai_credential_store.dart';
import 'package:nexecute/ai/repositories/ai_web_search_connection_profile_store.dart';
import 'package:nexecute/ai/repositories/ai_web_search_repository.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

final class AiWebSearchSettings extends StatefulWidget {
  const AiWebSearchSettings({super.key});

  @override
  State<AiWebSearchSettings> createState() => _AiWebSearchSettingsState();
}

final class _AiWebSearchSettingsState extends State<AiWebSearchSettings> {
  AiWebSearchSettingsController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final store = context.read<AiWebSearchConnectionProfileStore?>();
    final repository = context.read<AiWebSearchRepository?>();
    final credentials = context.read<AiCredentialStore?>();
    if (store == null || repository == null || credentials == null) return;
    final controller = AiWebSearchSettingsController(
      profileStore: store,
      searchRepository: repository,
      credentialStore: credentials,
    );
    controller.addListener(_changed);
    _controller = controller;
    unawaited(controller.initialize());
  }

  @override
  void dispose() {
    _controller?.removeListener(_changed);
    _controller?.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return Column(
      key: const Key('ai-web-search-settings'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 24),
        Text('Web search', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Search is a separate service. It requires explicit permission for '
          'each assistant request and sends the query to the selected provider.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (!controller.adapterAvailable) ...[
          const SizedBox(height: 8),
          Text(
            'Search execution is not installed yet. You can prepare a '
            'connection; requests remain disabled until the adapter is added.',
            key: const Key('ai-web-search-adapter-unavailable'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 14),
        if (controller.isLoading)
          const LinearProgressIndicator()
        else if (controller.loadError case final error?)
          Text('Could not load search connections: $error')
        else ...[
          for (final profile in controller.profiles) ...[
            _SearchProfileCard(
              profile: profile,
              active: controller.activeProfile?.id == profile.id,
              testing: controller.testingProfileId == profile.id,
              canTest: controller.adapterAvailable,
              result:
                  controller.testedProfileId == profile.id
                      ? controller.connectionResult?.message
                      : null,
              onSelect: () => controller.selectProfile(profile.id),
              onEdit: () => _edit(profile),
              onDelete: () => _delete(profile),
              onTest: () => controller.testConnection(profile),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton.tonalIcon(
            key: const Key('ai-add-web-search-connection'),
            onPressed: () => _edit(null),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add search connection'),
          ),
        ],
      ],
    );
  }

  Future<void> _edit(AiWebSearchConnectionProfile? profile) async {
    final controller = _controller;
    if (controller == null) return;
    final result = await showDialog<_SearchProfileEditResult>(
      context: context,
      builder:
          (_) => _SearchProfileEditor(profile: profile, controller: controller),
    );
    if (result == null || !mounted) return;
    try {
      await controller.saveProfile(
        result.profile,
        credential: result.credential,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save search connection: $error')),
        );
      }
    }
  }

  Future<void> _delete(AiWebSearchConnectionProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete search connection?'),
            content: Text('Delete “${profile.name}” and its stored API key?'),
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
    if (confirmed == true) await _controller?.deleteProfile(profile.id);
  }
}

final class _SearchProfileCard extends StatelessWidget {
  const _SearchProfileCard({
    required this.profile,
    required this.active,
    required this.testing,
    required this.canTest,
    required this.result,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onTest,
  });

  final AiWebSearchConnectionProfile profile;
  final bool active;
  final bool testing;
  final bool canTest;
  final String? result;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('ai-web-search-profile-${profile.id}'),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(active ? Icons.check_circle_rounded : Icons.circle_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${profile.provider.label} · '
                      '${profile.enabled ? 'Enabled' : 'Disabled'}',
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder:
                    (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              if (!active)
                TextButton(
                  onPressed: onSelect,
                  child: const Text('Use this connection'),
                ),
              TextButton.icon(
                onPressed: canTest && !testing ? onTest : null,
                icon: const Icon(Icons.network_check_rounded),
                label: Text(testing ? 'Testing…' : 'Test connection'),
              ),
            ],
          ),
          if (canTest)
            Text(
              'Testing uses one Brave Search API request.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (result != null) Text(result!),
        ],
      ),
    ),
  );
}

final class _SearchProfileEditResult {
  const _SearchProfileEditResult({required this.profile, this.credential});

  final AiWebSearchConnectionProfile profile;
  final String? credential;
}

final class _SearchProfileEditor extends StatefulWidget {
  const _SearchProfileEditor({required this.profile, required this.controller});

  final AiWebSearchConnectionProfile? profile;
  final AiWebSearchSettingsController controller;

  @override
  State<_SearchProfileEditor> createState() => _SearchProfileEditorState();
}

final class _SearchProfileEditorState extends State<_SearchProfileEditor> {
  final _formKey = GlobalKey<FormState>();
  late final String _id;
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _credential;
  late final TextEditingController _country;
  late final TextEditingController _language;
  late AiWebSearchProviderKind _providerKind;
  late AiWebSearchSafeSearch _safeSearch;
  late bool _enabled;
  bool _obscureCredential = true;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    final provider = AiWebSearchProviderCatalog.brave;
    _id = profile?.id ?? widget.controller.createProfileId();
    _providerKind = profile?.providerKind ?? provider.kind;
    _name = TextEditingController(text: profile?.name ?? 'Brave Search');
    _url = TextEditingController(
      text: profile?.baseUrl.toString() ?? provider.trustedBaseUrl,
    );
    _credential = TextEditingController();
    _country = TextEditingController(text: profile?.country ?? 'FI');
    _language = TextEditingController(text: profile?.searchLanguage ?? 'fi');
    _safeSearch = profile?.safeSearch ?? AiWebSearchSafeSearch.moderate;
    _enabled = profile?.enabled ?? false;
  }

  AiWebSearchProviderDescriptor get _provider =>
      AiWebSearchProviderCatalog.descriptor(_providerKind);

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _credential.dispose();
    _country.dispose();
    _language.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.profile == null
          ? 'Add search connection'
          : 'Edit search connection',
    ),
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
                key: const Key('ai-web-search-name-field'),
                controller: _name,
                decoration: const InputDecoration(labelText: 'Connection name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AiWebSearchProviderKind>(
                key: const Key('ai-web-search-provider-field'),
                initialValue: _providerKind,
                decoration: const InputDecoration(labelText: 'Provider'),
                items: [
                  for (final provider in AiWebSearchProviderCatalog.values)
                    DropdownMenuItem(
                      value: provider.kind,
                      child: Text(provider.label),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _providerKind = value;
                    final selected = AiWebSearchProviderCatalog.descriptor(
                      value,
                    );
                    _url.text = selected.trustedBaseUrl ?? '';
                    _name.text = selected.label;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('ai-web-search-url-field'),
                controller: _url,
                readOnly: _provider.hosted,
                decoration: const InputDecoration(labelText: 'Search endpoint'),
                keyboardType: TextInputType.url,
                validator: (value) {
                  final uri = Uri.tryParse(value?.trim() ?? '');
                  if (uri == null ||
                      !uri.hasScheme ||
                      uri.host.isEmpty ||
                      (uri.scheme != 'http' && uri.scheme != 'https')) {
                    return 'Enter a valid HTTP or HTTPS endpoint.';
                  }
                  return null;
                },
              ),
              if (_provider.requiresCredential) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('ai-web-search-api-key-field'),
                  controller: _credential,
                  obscureText: _obscureCredential,
                  maxLength: aiMaxCredentialCharacters,
                  decoration: InputDecoration(
                    labelText:
                        widget.profile?.credentialReference == null
                            ? 'API key'
                            : 'Replacement API key (optional)',
                    suffixIcon: IconButton(
                      onPressed:
                          () => setState(
                            () => _obscureCredential = !_obscureCredential,
                          ),
                      icon: Icon(
                        _obscureCredential
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (widget.profile?.credentialReference == null &&
                        (value?.trim().isEmpty ?? true)) {
                      return 'Enter the provider API key.';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('ai-web-search-country-field'),
                      controller: _country,
                      decoration: const InputDecoration(labelText: 'Country'),
                      validator:
                          (value) =>
                              RegExp(r'^[A-Za-z]{2}$').hasMatch(value ?? '')
                                  ? null
                                  : 'Use a two-letter country code.',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const Key('ai-web-search-language-field'),
                      controller: _language,
                      decoration: const InputDecoration(labelText: 'Language'),
                      validator:
                          (value) =>
                              RegExp(
                                    r'^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$',
                                  ).hasMatch(value ?? '')
                                  ? null
                                  : 'Enter a language code.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AiWebSearchSafeSearch>(
                key: const Key('ai-web-search-safe-search-field'),
                initialValue: _safeSearch,
                decoration: const InputDecoration(labelText: 'SafeSearch'),
                items: [
                  for (final value in AiWebSearchSafeSearch.values)
                    DropdownMenuItem(value: value, child: Text(value.name)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _safeSearch = value);
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                key: const Key('ai-web-search-enabled-field'),
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                onChanged:
                    kIsWeb ? null : (value) => setState(() => _enabled = value),
                title: const Text('Enable this search connection'),
                subtitle: Text(
                  kIsWeb
                      ? 'Reusable search credentials are unavailable in the web app.'
                      : 'Queries may incur separate provider charges. Each assistant request still needs explicit permission.',
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (_provider.documentationUrl case final url?)
                    _ProviderLink(label: 'Documentation', url: url),
                  if (_provider.keyManagementUrl case final url?)
                    _ProviderLink(label: 'Manage API keys', url: url),
                  if (_provider.billingUrl case final url?)
                    _ProviderLink(label: 'Plans and billing', url: url),
                ],
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
        key: const Key('ai-web-search-save'),
        onPressed: _save,
        child: const Text('Save'),
      ),
    ],
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _SearchProfileEditResult(
        profile: AiWebSearchConnectionProfile(
          id: _id,
          name: _name.text.trim(),
          providerKind: _providerKind,
          baseUrl: Uri.parse(_url.text.trim()),
          enabled: _enabled,
          credentialReference: widget.profile?.credentialReference,
          country: _country.text.trim().toUpperCase(),
          searchLanguage: _language.text.trim(),
          safeSearch: _safeSearch,
        ),
        credential: _credential.text.trim(),
      ),
    );
  }
}

final class _ProviderLink extends StatelessWidget {
  const _ProviderLink({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () => launchUrl(Uri.parse(url)),
    icon: const Icon(Icons.open_in_new_rounded),
    label: Text(label),
  );
}
