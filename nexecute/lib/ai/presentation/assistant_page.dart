import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/shared/adaptive_navigation_shell.dart';
import 'package:nexecute/shared/app_shortcuts.dart';
import 'package:nexecute/shared/bottom_sheet_safe_area.dart';
import 'package:provider/provider.dart';

class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key, this.embedded = false, this.onOpenSettings});

  final bool embedded;
  final VoidCallback? onOpenSettings;

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  late final AiChatController _controller;
  late final AiApplicationContextReadService _contextReadService;
  final _composerController = TextEditingController();
  final _composerFocusNode = FocusNode(debugLabel: 'Assistant composer');
  final _scrollController = ScrollController();
  final Map<String, AiApplicationContextEnvelope> _noteContexts = {};
  AiSkillStore? _skillStore;
  StreamSubscription<List<AiSkillMetadata>>? _skillSubscription;
  List<AiSkillMetadata> _skillCatalog = const [];
  Object? _skillCatalogError;
  AiApplicationContextEnvelope? _taskContext;
  AiApplicationContextEnvelope? _eventContext;
  DateTime? _contextGeneratedAt;
  bool _isLoadingContext = false;

  @override
  void initState() {
    super.initState();
    _contextReadService = context.read<AiApplicationContextReadService>();
    final assistantRepository = context.read<AiAssistantRepository>();
    _skillStore = context.read<AiSkillStore?>();
    _controller = AiChatController(
      assistantRepository: assistantRepository,
      connectionProfileStore: context.read<AiConnectionProfileStore>(),
      conversationStore: context.read<AiConversationStore>(),
      skillStore: _skillStore,
      skillPreferencesStore: context.read<AiSkillPreferencesStore?>(),
      readToolCoordinator: AiReadToolCoordinator(
        assistantRepository: assistantRepository,
        readService: _contextReadService,
      ),
    )..addListener(_onControllerChanged);
    final skillStore = _skillStore;
    if (skillStore != null && skillStore.isAvailable) {
      _skillSubscription = skillStore.watchSkills().listen(
        (skills) {
          if (!mounted) return;
          setState(() {
            _skillCatalog = skills;
            _skillCatalogError = null;
          });
        },
        onError: (Object error) {
          if (!mounted) return;
          setState(() => _skillCatalogError = error);
        },
      );
    }
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    unawaited(_skillSubscription?.cancel());
    _composerController.dispose();
    _composerFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _controller.activeProfile;
    final actions = [
      IconButton(
        key: const Key('assistant-new-conversation'),
        tooltip: 'New conversation',
        onPressed: () => unawaited(_controller.startNewConversation()),
        icon: const Icon(Icons.add_comment_outlined),
      ),
      IconButton(
        key: const Key('assistant-conversation-list'),
        tooltip: 'Conversations',
        onPressed: _showConversations,
        icon: const Icon(Icons.history_rounded),
      ),
    ];
    final assistantBody = SafeArea(
      child: FocusTraversalGroup(
        child: AdaptiveContentFrame(
          contentKey: const Key('assistant-content-frame'),
          child: Column(
            children: [
              if (_controller.errorMessage case final error?)
                _ErrorBanner(message: error, onDismiss: _controller.clearError),
              Expanded(child: _buildConversation()),
              if (_applicationContext case final applicationContext?)
                _ApplicationContextBar(
                  contextEnvelope: applicationContext,
                  noteTitles: [
                    for (final envelope in _noteContexts.values)
                      (envelope.attachments.single
                              as AiSelectedNotesContextAttachment)
                          .notes
                          .single
                          .title,
                  ],
                  hasTasks: _taskContext != null,
                  hasEvents: _eventContext != null,
                  onRemoveNote: _removeNoteAt,
                  onRemoveTasks: _removeTasks,
                  onRemoveEvents: _removeEvents,
                  onPreview: () => _showContextPreview(applicationContext),
                ),
              _SkillActivationBar(
                references: _controller.effectiveSkills,
                metadata: _skillCatalog,
                appliesToNextRequest: _controller.nextRequestSkills != null,
                storageAvailable:
                    _skillStore?.isAvailable == true &&
                    _skillCatalogError == null,
                onPick: _showSkillPicker,
                onRemove: _removeSkill,
                onClear: _clearSkills,
                onPreview: _showInstructionPreview,
              ),
              _Composer(
                controller: _composerController,
                focusNode: _composerFocusNode,
                enabled: !_controller.isLoading && profile != null,
                isGenerating: _controller.isGenerating,
                onSend: _send,
                onStop: () => unawaited(_controller.stopResponse()),
                onAttach: _isLoadingContext ? null : _showAttachmentMenu,
                isLoadingContext: _isLoadingContext,
              ),
            ],
          ),
        ),
      ),
    );
    return Shortcuts(
      shortcuts: AppShortcutBindings.assistant,
      child: Actions(
        actions: {
          FocusAssistantComposerIntent:
              CallbackAction<FocusAssistantComposerIntent>(
                onInvoke: (_) {
                  if (isCurrentAppRoute(context)) {
                    _composerFocusNode.requestFocus();
                  }
                  return null;
                },
              ),
          SaveAppIntent: CallbackAction<SaveAppIntent>(
            onInvoke: (_) {
              if (isCurrentAppRoute(context) &&
                  _composerFocusNode.hasFocus &&
                  !_controller.isLoading &&
                  profile != null) {
                unawaited(_send(_composerController.text));
              }
              return null;
            },
          ),
          CancelAppIntent: CallbackAction<CancelAppIntent>(
            onInvoke: (_) {
              if (!isCurrentAppRoute(context)) return null;
              if (_composerFocusNode.hasFocus) {
                _composerFocusNode.unfocus();
              } else if (!widget.embedded) {
                Navigator.maybePop(context);
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child:
              widget.embedded
                  ? Material(
                    key: const Key('desktop-assistant-tab'),
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 48,
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              if (profile != null)
                                Expanded(
                                  child: Text(
                                    '${profile.name} · ${profile.modelId}',
                                    key: const Key(
                                      'assistant-active-connection',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                )
                              else
                                const Spacer(),
                              ...actions,
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(child: assistantBody),
                      ],
                    ),
                  )
                  : Scaffold(
                    appBar: AppBar(
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Assistant'),
                          if (profile != null)
                            Text(
                              '${profile.name} · ${profile.modelId}',
                              key: const Key('assistant-active-connection'),
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                      actions: actions,
                    ),
                    body: assistantBody,
                  ),
        ),
      ),
    );
  }

  Widget _buildConversation() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.activeProfile == null) {
      return _AssistantEmptyState(
        icon: Icons.hub_outlined,
        title: 'Connect an AI endpoint',
        message:
            'Create and select a connection profile before starting a chat.',
        actionLabel: 'Open Settings',
        onAction: _openSettings,
      );
    }
    if (_controller.messages.isEmpty) {
      return const _AssistantEmptyState(
        icon: Icons.auto_awesome_outlined,
        title: 'Start a conversation',
        message:
            'Messages sync through your account. AI requests go only to the selected endpoint.',
      );
    }
    return ListView.builder(
      key: const Key('assistant-message-list'),
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
      itemCount: _controller.messages.length,
      itemBuilder: (context, index) {
        final message = _controller.messages[index];
        return _MessageBubble(
          message: message,
          reasoning: _controller.reasoningForMessage(message.id),
          onOpenSettings: _openSettings,
          onRetry:
              message.role == AiMessageRole.assistant &&
                      (message.status == AiMessageStatus.failed ||
                          message.status == AiMessageStatus.cancelled)
                  ? () => unawaited(_controller.retryLastResponse())
                  : null,
        );
      },
    );
  }

  void _openSettings() {
    if (widget.onOpenSettings case final callback?) {
      callback();
    } else {
      Navigator.pushNamed(context, '/settings');
    }
  }

  AiApplicationContextEnvelope? get _applicationContext {
    final sources = <AiApplicationContextEnvelope>[
      ..._noteContexts.values,
      if (_taskContext case final context?) context,
      if (_eventContext case final context?) context,
    ];
    if (sources.isEmpty) return null;
    return AiApplicationContextBuilder.compose(
      generatedAt: _contextGeneratedAt ?? DateTime.now(),
      sources: sources,
    );
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _composerController.clear();
    final sent = await _controller.send(
      text,
      applicationContext: _applicationContext,
      readToolExecutionScope: _readToolExecutionScope,
    );
    if (!mounted) return;
    if (sent) {
      setState(_clearApplicationContext);
      return;
    }
    if (_controller.skillResolutionError != null) {
      _composerController.text = text;
      await _showSkillRecovery(text);
    }
  }

  Future<void> _showSkillRecovery(String text) async {
    final failure = _controller.skillResolutionError;
    if (failure == null || !mounted) return;
    final action = await showDialog<_SkillRecoveryAction>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Active skills need attention'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final issue in failure.issues)
                  Text('• ${issue.reference.id}: ${_issueLabel(issue.kind)}'),
                const SizedBox(height: 12),
                const Text(
                  'Review the active set, import or replace the local skill, '
                  'or explicitly send this message without skills.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                key: const Key('assistant-review-skills'),
                onPressed:
                    () => Navigator.pop(context, _SkillRecoveryAction.review),
                child: const Text('Review skills'),
              ),
              FilledButton(
                key: const Key('assistant-continue-without-skills'),
                onPressed:
                    () => Navigator.pop(
                      context,
                      _SkillRecoveryAction.continueWithoutSkills,
                    ),
                child: const Text('Send without skills'),
              ),
            ],
          ),
    );
    if (!mounted) return;
    switch (action) {
      case _SkillRecoveryAction.review:
        await _showSkillPicker();
      case _SkillRecoveryAction.continueWithoutSkills:
        _composerController.clear();
        final sent = await _controller.send(
          text,
          applicationContext: _applicationContext,
          readToolExecutionScope: _readToolExecutionScope,
          skillMismatchAction: AiSkillMismatchAction.continueWithoutSkills,
        );
        if (!mounted) return;
        if (sent) {
          setState(_clearApplicationContext);
        } else {
          _composerController.text = text;
        }
      case null:
        return;
    }
  }

  Future<void> _showSkillPicker() async {
    if (_skillStore?.isAvailable != true || _skillCatalogError != null) {
      _showContextError(
        'Skill storage is unavailable. Ordinary chat still works without skills.',
      );
      return;
    }
    final selection = await showModalBottomSheet<_SkillSelection>(
      context: context,
      isScrollControlled: true,
      constraints: adaptiveSheetConstraints(context),
      builder:
          (sheetContext) => BottomSheetSafeArea(
            child: _SkillPickerSheet(
              skills: _skillCatalog,
              conversationReferences: _controller.conversationSkills,
              nextRequestReferences: _controller.nextRequestSkills,
              onManage: () {
                Navigator.pop(sheetContext);
                _openSettings();
              },
            ),
          ),
    );
    if (selection == null) return;
    await _controller.setActiveSkills(
      selection.references,
      scope: selection.scope,
    );
  }

  Future<void> _removeSkill(String skillId) => _setEffectiveSkills(
    _controller.effectiveSkills.where((skill) => skill.id != skillId),
  );

  Future<void> _clearSkills() => _setEffectiveSkills(const []);

  Future<void> _setEffectiveSkills(Iterable<AiSkillReference> references) =>
      _controller.setActiveSkills(
        references,
        scope:
            _controller.nextRequestSkills == null
                ? AiSkillActivationScope.conversation
                : AiSkillActivationScope.nextRequest,
      );

  Future<void> _showInstructionPreview() async {
    final profile = _controller.activeProfile;
    final metadata = {for (final skill in _skillCatalog) skill.id: skill};
    final sources = <String>['Immutable Nexecute policy'];
    if (profile?.systemPrompt.trim().isNotEmpty ?? false) {
      sources.add(
        'Connection profile preferences · ${profile!.name} · '
        '${profile.systemPrompt.trim().length} characters',
      );
    }
    for (final reference in _controller.effectiveSkills) {
      sources.add(
        'Active skill · ${metadata[reference.id]?.name ?? reference.id} · '
        'revision ${reference.contentHash.substring(0, 12)}…',
      );
    }
    sources.add('Trusted app-owned workflow constraints, when present');
    await showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Instruction source order'),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < sources.length; index++) ...[
                    Text('${index + 1}. ${sources[index]}'),
                    const SizedBox(height: 8),
                  ],
                  const Divider(),
                  const Text(
                    'This preview intentionally excludes credentials, skill '
                    'bodies, attached application data, conversation content, '
                    'and hidden provider payloads.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  AiReadToolExecutionScope? get _readToolExecutionScope {
    final taskAccess = _taskContext != null;
    AiEventsContextAttachment? eventAttachment;
    for (final attachment in _eventContext?.attachments ?? const []) {
      if (attachment is AiEventsContextAttachment) {
        eventAttachment = attachment;
        break;
      }
    }
    final noteMapping = <String, String>{};
    var index = 1;
    for (final noteId in _noteContexts.keys) {
      noteMapping['note_$index'] = noteId;
      index++;
    }
    if (!taskAccess && eventAttachment == null && noteMapping.isEmpty) {
      return null;
    }
    final authorization = AiReadToolAuthorization(
      allowActiveTasks: taskAccess,
      eventRange: eventAttachment?.range,
      allowedNoteReferences: noteMapping.keys.toSet(),
    );
    try {
      return AiReadToolExecutionScope(
        authorization: authorization,
        noteIdsByReference: noteMapping,
      );
    } on ArgumentError {
      return null;
    }
  }

  Future<void> _showAttachmentMenu() async {
    final choice = await showModalBottomSheet<_AttachmentChoice>(
      context: context,
      constraints: adaptiveSheetConstraints(context),
      builder: (context) => const BottomSheetSafeArea(child: _AttachmentMenu()),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _AttachmentChoice.note:
        await _selectNote();
      case _AttachmentChoice.tasks:
        await _loadContext(
          () => _contextReadService.listTasks(
            scope: AiApplicationReadScope(allowActiveTasks: true),
          ),
          (value) => _taskContext = value,
        );
      case _AttachmentChoice.todayEvents:
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        await _attachEvents(
          CalendarQueryRange(
            startInclusive: start,
            endExclusive: DateTime(now.year, now.month, now.day + 1),
          ),
        );
      case _AttachmentChoice.customEvents:
        await _selectCustomEventRange();
    }
  }

  Future<void> _selectNote() async {
    if (_noteContexts.length >= AiApplicationContextLimits.maxSelectedNotes) {
      _showContextError('Remove a note before attaching another one.');
      return;
    }
    final selected = await showDialog<_SelectedNoteContext>(
      context: context,
      builder: (_) => _NoteContextPicker(service: _contextReadService),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _ensureContextTimestamp();
      _noteContexts[selected.id] = selected.context;
    });
  }

  Future<void> _selectCustomEventRange() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      currentDate: now,
      helpText: 'Select up to 31 days',
    );
    if (!mounted || selected == null) return;
    final days = selected.end.difference(selected.start).inDays + 1;
    if (days > AiApplicationContextLimits.maxEventRangeDays) {
      _showContextError('Choose an event range of 31 days or less.');
      return;
    }
    await _attachEvents(
      CalendarQueryRange(
        startInclusive: selected.start,
        endExclusive: DateTime(
          selected.end.year,
          selected.end.month,
          selected.end.day + 1,
        ),
      ),
    );
  }

  Future<void> _attachEvents(CalendarQueryRange range) => _loadContext(
    () => _contextReadService.eventsForDateRange(
      scope: AiApplicationReadScope(eventRange: range),
      range: range,
    ),
    (value) => _eventContext = value,
  );

  Future<void> _loadContext(
    Future<AiApplicationContextEnvelope> Function() load,
    void Function(AiApplicationContextEnvelope) attach,
  ) async {
    setState(() => _isLoadingContext = true);
    try {
      final value = await load();
      if (!mounted) return;
      setState(() {
        _ensureContextTimestamp();
        attach(value);
      });
    } catch (error) {
      if (mounted) _showContextError(error.toString());
    } finally {
      if (mounted) setState(() => _isLoadingContext = false);
    }
  }

  void _removeNoteAt(int index) {
    setState(() {
      _noteContexts.remove(_noteContexts.keys.elementAt(index));
      _resetContextTimestampIfEmpty();
    });
  }

  void _removeTasks() {
    setState(() {
      _taskContext = null;
      _resetContextTimestampIfEmpty();
    });
  }

  void _removeEvents() {
    setState(() {
      _eventContext = null;
      _resetContextTimestampIfEmpty();
    });
  }

  void _ensureContextTimestamp() {
    _contextGeneratedAt ??= DateTime.now();
  }

  void _resetContextTimestampIfEmpty() {
    if (_noteContexts.isEmpty &&
        _taskContext == null &&
        _eventContext == null) {
      _contextGeneratedAt = null;
    }
  }

  void _clearApplicationContext() {
    _noteContexts.clear();
    _taskContext = null;
    _eventContext = null;
    _contextGeneratedAt = null;
  }

  Future<void> _showContextPreview(
    AiApplicationContextEnvelope applicationContext,
  ) => showDialog<void>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('Context for next message'),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: SelectableText(
                applicationContext.encode(),
                key: const Key('assistant-context-preview-json'),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
  );

  void _showContextError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showConversations() async {
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      constraints: adaptiveSheetConstraints(context),
      builder:
          (context) => BottomSheetSafeArea(
            child: _ConversationSheet(
              conversations: _controller.conversations,
              activeConversationId: _controller.conversation?.id,
              onDelete: (id) async {
                await _controller.deleteConversation(id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ),
    );
    if (selectedId == null) return;
    await _controller.openConversation(selectedId);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.isGenerating,
    required this.onSend,
    required this.onStop,
    required this.onAttach,
    required this.isLoadingContext,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool isGenerating;
  final ValueChanged<String> onSend;
  final VoidCallback onStop;
  final VoidCallback? onAttach;
  final bool isLoadingContext;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          10 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              key: const Key('assistant-attach-context'),
              tooltip: 'Attach application context',
              onPressed: enabled && !isGenerating ? onAttach : null,
              icon:
                  isLoadingContext
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.attach_file_rounded),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Tooltip(
                message:
                    'Focus composer: ${AppShortcutLabels.assistantComposer}',
                child: TextField(
                  key: const Key('assistant-composer'),
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled && !isGenerating,
                  minLines: 1,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: 'Message the assistant',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (isGenerating)
              IconButton.filled(
                key: const Key('assistant-stop'),
                tooltip: 'Stop response',
                onPressed: onStop,
                icon: const Icon(Icons.stop_rounded),
              )
            else
              IconButton.filled(
                key: const Key('assistant-send'),
                tooltip: 'Send',
                onPressed: enabled ? () => onSend(controller.text) : null,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

enum _SkillRecoveryAction { review, continueWithoutSkills }

String _issueLabel(AiSkillResolutionIssueKind kind) => switch (kind) {
  AiSkillResolutionIssueKind.missing => 'not installed on this device',
  AiSkillResolutionIssueKind.changed => 'local revision changed',
  AiSkillResolutionIssueKind.disabled => 'disabled',
  AiSkillResolutionIssueKind.storageUnavailable => 'storage unavailable',
  AiSkillResolutionIssueKind.promptBudgetUnavailable =>
    'multiple skills require Step 11E prompt budgeting',
};

class _SkillActivationBar extends StatelessWidget {
  const _SkillActivationBar({
    required this.references,
    required this.metadata,
    required this.appliesToNextRequest,
    required this.storageAvailable,
    required this.onPick,
    required this.onRemove,
    required this.onClear,
    required this.onPreview,
  });

  final List<AiSkillReference> references;
  final List<AiSkillMetadata> metadata;
  final bool appliesToNextRequest;
  final bool storageAvailable;
  final VoidCallback onPick;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final skill in metadata) skill.id: skill};
    return Material(
      key: const Key('assistant-skill-bar'),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    !storageAvailable
                        ? 'Skills unavailable · chat continues without them'
                        : appliesToNextRequest
                        ? 'Skills for next message'
                        : references.isEmpty
                        ? 'Skills · none active'
                        : 'Active skills for this conversation',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                IconButton(
                  key: const Key('assistant-preview-instructions'),
                  tooltip: 'Preview instruction source order',
                  onPressed: onPreview,
                  icon: const Icon(Icons.visibility_outlined, size: 20),
                ),
                TextButton.icon(
                  key: const Key('assistant-pick-skills'),
                  onPressed: storageAvailable ? onPick : null,
                  icon: const Icon(Icons.psychology_alt_outlined, size: 20),
                  label: const Text('Skills'),
                ),
                if (references.isNotEmpty)
                  IconButton(
                    key: const Key('assistant-clear-skills'),
                    tooltip: 'Deactivate all skills',
                    onPressed: onClear,
                    icon: const Icon(Icons.layers_clear_outlined, size: 20),
                  ),
              ],
            ),
            if (references.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final reference in references)
                    InputChip(
                      key: ValueKey('assistant-skill-${reference.id}'),
                      avatar: Icon(
                        _skillIcon(reference, byId[reference.id]),
                        size: 18,
                      ),
                      label: Text(_skillLabel(reference, byId[reference.id])),
                      onDeleted: () => onRemove(reference.id),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static IconData _skillIcon(
    AiSkillReference reference,
    AiSkillMetadata? metadata,
  ) {
    if (metadata == null) return Icons.cloud_off_outlined;
    if (!metadata.isEnabled) return Icons.pause_circle_outline_rounded;
    if (metadata.contentHash != reference.contentHash) {
      return Icons.sync_problem_rounded;
    }
    return Icons.psychology_alt_rounded;
  }

  static String _skillLabel(
    AiSkillReference reference,
    AiSkillMetadata? metadata,
  ) {
    if (metadata == null) return '${reference.id} · unavailable';
    if (!metadata.isEnabled) return '${metadata.name} · disabled';
    if (metadata.contentHash != reference.contentHash) {
      return '${metadata.name} · changed';
    }
    return metadata.name;
  }
}

final class _SkillSelection {
  const _SkillSelection({required this.scope, required this.references});

  final AiSkillActivationScope scope;
  final List<AiSkillReference> references;
}

class _SkillPickerSheet extends StatefulWidget {
  const _SkillPickerSheet({
    required this.skills,
    required this.conversationReferences,
    required this.nextRequestReferences,
    required this.onManage,
  });

  final List<AiSkillMetadata> skills;
  final List<AiSkillReference> conversationReferences;
  final List<AiSkillReference>? nextRequestReferences;
  final VoidCallback onManage;

  @override
  State<_SkillPickerSheet> createState() => _SkillPickerSheetState();
}

class _SkillPickerSheetState extends State<_SkillPickerSheet> {
  late AiSkillActivationScope _scope;
  late Set<String> _selectedIds;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scope =
        widget.nextRequestReferences == null
            ? AiSkillActivationScope.conversation
            : AiSkillActivationScope.nextRequest;
    _selectedIds = _referencesFor(_scope).map((skill) => skill.id).toSet();
  }

  List<AiSkillReference> _referencesFor(AiSkillActivationScope scope) =>
      scope == AiSkillActivationScope.conversation
          ? widget.conversationReferences
          : widget.nextRequestReferences ?? widget.conversationReferences;

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible =
        widget.skills
            .where(
              (skill) =>
                  query.isEmpty ||
                  skill.name.toLowerCase().contains(query) ||
                  skill.description.toLowerCase().contains(query) ||
                  skill.id.toLowerCase().contains(query),
            )
            .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          ListTile(
            title: const Text('Choose active skills'),
            subtitle: const Text(
              'Choose one enabled skill. Multi-skill budgeting is added in Step 11E.',
            ),
            trailing: IconButton(
              tooltip: 'Manage skills in Settings',
              onPressed: widget.onManage,
              icon: const Icon(Icons.settings_outlined),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<AiSkillActivationScope>(
              key: const Key('assistant-skill-scope'),
              segments: const [
                ButtonSegment(
                  value: AiSkillActivationScope.conversation,
                  label: Text('This conversation'),
                  icon: Icon(Icons.forum_outlined),
                ),
                ButtonSegment(
                  value: AiSkillActivationScope.nextRequest,
                  label: Text('Next message only'),
                  icon: Icon(Icons.looks_one_outlined),
                ),
              ],
              selected: {_scope},
              onSelectionChanged: (selection) {
                final scope = selection.single;
                setState(() {
                  _scope = scope;
                  _selectedIds =
                      _referencesFor(scope).map((skill) => skill.id).toSet();
                });
              },
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const Key('assistant-skill-search'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search local skills',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child:
                widget.skills.isEmpty
                    ? const Center(
                      child: Text(
                        'No local skills. Create or import one in Settings.',
                      ),
                    )
                    : visible.isEmpty
                    ? const Center(child: Text('No skills match this search.'))
                    : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final skill = visible[index];
                        final selected = _selectedIds.contains(skill.id);
                        return CheckboxListTile(
                          key: ValueKey('assistant-skill-option-${skill.id}'),
                          value: selected,
                          onChanged:
                              skill.isEnabled
                                  ? (value) {
                                    setState(() {
                                      if (value ?? false) {
                                        _selectedIds.clear();
                                        _selectedIds.add(skill.id);
                                      } else {
                                        _selectedIds.remove(skill.id);
                                      }
                                    });
                                  }
                                  : null,
                          title: Text(skill.name),
                          subtitle: Text(
                            skill.isEnabled
                                ? selected
                                    ? 'Active · ${skill.description}'
                                    : 'Inactive · ${skill.description}'
                                : 'Disabled · ${skill.description}',
                          ),
                        );
                      },
                    ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                TextButton(
                  key: const Key('assistant-skill-deactivate-all'),
                  onPressed: () => setState(_selectedIds.clear),
                  child: const Text('Deactivate all'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('assistant-skill-apply'),
                  onPressed:
                      _selectedIds.length > 1
                          ? null
                          : () {
                            final references = [
                              for (final skill in widget.skills)
                                if (skill.isEnabled &&
                                    _selectedIds.contains(skill.id))
                                  AiSkillReference(
                                    id: skill.id,
                                    contentHash: skill.contentHash,
                                  ),
                            ];
                            Navigator.pop(
                              context,
                              _SkillSelection(
                                scope: _scope,
                                references: references,
                              ),
                            );
                          },
                  child: Text(
                    _selectedIds.length > 1 ? 'Select one skill' : 'Apply',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _AttachmentChoice { note, tasks, todayEvents, customEvents }

class _AttachmentMenu extends StatelessWidget {
  const _AttachmentMenu();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Wrap(
        children: [
          const ListTile(
            title: Text('Attach application context'),
            subtitle: Text('Shared with the next message only'),
          ),
          ListTile(
            leading: const Icon(Icons.note_outlined),
            title: const Text('Select a note'),
            onTap: () => Navigator.pop(context, _AttachmentChoice.note),
          ),
          ListTile(
            leading: const Icon(Icons.task_alt_outlined),
            title: const Text('Unfinished tasks'),
            onTap: () => Navigator.pop(context, _AttachmentChoice.tasks),
          ),
          ListTile(
            leading: const Icon(Icons.today_outlined),
            title: const Text("Today's events"),
            onTap: () => Navigator.pop(context, _AttachmentChoice.todayEvents),
          ),
          ListTile(
            leading: const Icon(Icons.date_range_outlined),
            title: const Text('Custom event range'),
            subtitle: const Text('Up to 31 days'),
            onTap: () => Navigator.pop(context, _AttachmentChoice.customEvents),
          ),
        ],
      ),
    );
  }
}

class _ApplicationContextBar extends StatelessWidget {
  const _ApplicationContextBar({
    required this.contextEnvelope,
    required this.noteTitles,
    required this.hasTasks,
    required this.hasEvents,
    required this.onRemoveNote,
    required this.onRemoveTasks,
    required this.onRemoveEvents,
    required this.onPreview,
  });

  final AiApplicationContextEnvelope contextEnvelope;
  final List<String> noteTitles;
  final bool hasTasks;
  final bool hasEvents;
  final ValueChanged<int> onRemoveNote;
  final VoidCallback onRemoveTasks;
  final VoidCallback onRemoveEvents;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Context for next message · '
                    '${contextEnvelope.serializedCharacterCount} characters',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                TextButton(
                  key: const Key('assistant-preview-context'),
                  onPressed: onPreview,
                  child: const Text('Preview exact data'),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var index = 0; index < noteTitles.length; index++)
                  InputChip(
                    key: ValueKey('assistant-note-context-$index'),
                    avatar: const Icon(Icons.note_outlined, size: 18),
                    label: Text(noteTitles[index]),
                    onDeleted: () => onRemoveNote(index),
                  ),
                if (hasTasks)
                  InputChip(
                    key: const Key('assistant-task-context'),
                    avatar: const Icon(Icons.task_alt_outlined, size: 18),
                    label: const Text('Unfinished tasks'),
                    onDeleted: onRemoveTasks,
                  ),
                if (hasEvents)
                  InputChip(
                    key: const Key('assistant-event-context'),
                    avatar: const Icon(Icons.event_outlined, size: 18),
                    label: const Text('Events'),
                    onDeleted: onRemoveEvents,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedNoteContext {
  const _SelectedNoteContext({required this.id, required this.context});

  final String id;
  final AiApplicationContextEnvelope context;
}

class _NoteContextPicker extends StatefulWidget {
  const _NoteContextPicker({required this.service});

  final AiApplicationContextReadService service;

  @override
  State<_NoteContextPicker> createState() => _NoteContextPickerState();
}

class _NoteContextPickerState extends State<_NoteContextPicker> {
  final _queryController = TextEditingController();
  List<_SelectedNoteContext> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select a note'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('assistant-note-search'),
              controller: _queryController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => unawaited(_search()),
              decoration: InputDecoration(
                hintText: 'Search notes',
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  onPressed: _loading ? null : () => unawaited(_search()),
                  icon:
                      _loading
                          ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.search),
                ),
              ),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final result in _results)
                      ListTile(
                        leading: const Icon(Icons.note_outlined),
                        title: Text(
                          ((result.context.attachments.single
                                      as AiSelectedNotesContextAttachment)
                                  .notes
                                  .single)
                              .title,
                        ),
                        onTap: () => Navigator.pop(context, result),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.service.searchNotes(
        scope: AiApplicationReadScope(allowNoteSearch: true),
        query: _queryController.text,
      );
      final attachment =
          result.context.attachments.single as AiSelectedNotesContextAttachment;
      final values = <_SelectedNoteContext>[];
      for (var index = 0; index < attachment.notes.length; index++) {
        values.add(
          _SelectedNoteContext(
            id: result.sourceNoteIds[index],
            context: AiApplicationContextEnvelope(
              generatedAt: result.context.generatedAt,
              attachments: [
                AiSelectedNotesContextAttachment(
                  notes: [attachment.notes[index]],
                  omittedCount: 0,
                ),
              ],
            ),
          ),
        );
      }
      if (mounted) setState(() => _results = values);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.reasoning,
    this.onRetry,
    this.onOpenSettings,
  });

  final AiChatMessage message;
  final String? reasoning;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AiMessageRole.user;
    final visibleReasoning = reasoning?.trim() ?? '';
    final hasReasoning = !isUser && visibleReasoning.isNotEmpty;
    final colors = Theme.of(context).colorScheme;
    final statusText = switch (message.status) {
      AiMessageStatus.streaming => 'Thinking…',
      AiMessageStatus.cancelled => 'Stopped',
      AiMessageStatus.failed when message.diagnostic != null => null,
      AiMessageStatus.failed => message.errorMessage ?? 'Response failed',
      AiMessageStatus.complete => null,
    };
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        key: ValueKey('assistant-message-${message.id}'),
        constraints: const BoxConstraints(maxWidth: 680),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isUser ? colors.primaryContainer : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: isUser ? null : const Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasReasoning) ...[
              _ReasoningPanel(
                key: ValueKey('assistant-reasoning-${message.id}'),
                text: visibleReasoning,
                initiallyExpanded:
                    message.status == AiMessageStatus.streaming &&
                    message.content.isEmpty,
                streaming: message.status == AiMessageStatus.streaming,
                completed: message.status == AiMessageStatus.complete,
              ),
              if (message.content.isNotEmpty) const SizedBox(height: 10),
            ],
            if (message.content.isNotEmpty)
              SelectableText(message.content)
            else if (message.status == AiMessageStatus.streaming &&
                !hasReasoning)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (statusText != null) ...[
              const SizedBox(height: 7),
              Text(
                statusText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      message.status == AiMessageStatus.failed
                          ? colors.error
                          : colors.onSurfaceVariant,
                ),
              ),
            ],
            if (message.diagnostic case final diagnostic?) ...[
              const SizedBox(height: 9),
              AiDiagnosticPanel(
                diagnostic: diagnostic,
                compact: true,
                onAction:
                    onOpenSettings ??
                    () => Navigator.pushNamed(context, '/settings'),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                key: const Key('assistant-retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReasoningPanel extends StatefulWidget {
  const _ReasoningPanel({
    super.key,
    required this.text,
    required this.initiallyExpanded,
    required this.streaming,
    required this.completed,
  });

  final String text;
  final bool initiallyExpanded;
  final bool streaming;
  final bool completed;

  @override
  State<_ReasoningPanel> createState() => _ReasoningPanelState();
}

class _ReasoningPanelState extends State<_ReasoningPanel> {
  late final ExpansibleController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ExpansibleController();
  }

  @override
  void didUpdateWidget(covariant _ReasoningPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.completed && widget.completed && _controller.isExpanded) {
      _controller.collapse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          color: Colors.transparent,
          child: ExpansionTile(
            controller: _controller,
            initiallyExpanded: widget.initiallyExpanded,
            maintainState: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 10),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            leading:
                widget.streaming
                    ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.psychology_outlined, size: 20),
            title: const Text('Reasoning'),
            subtitle: const Text('Session only · not synchronized'),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  widget.text,
                  key: const Key('assistant-reasoning-text'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantEmptyState extends StatelessWidget {
  const _AssistantEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 52,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      key: const Key('assistant-error'),
      content: Text(message),
      leading: const Icon(Icons.error_outline_rounded),
      actions: [TextButton(onPressed: onDismiss, child: const Text('Dismiss'))],
    );
  }
}

class _ConversationSheet extends StatelessWidget {
  const _ConversationSheet({
    required this.conversations,
    required this.activeConversationId,
    required this.onDelete,
  });

  final List<AiConversation> conversations;
  final String? activeConversationId;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Conversations',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child:
                  conversations.isEmpty
                      ? const Center(child: Text('No conversations yet.'))
                      : ListView.builder(
                        itemCount: conversations.length,
                        itemBuilder: (context, index) {
                          final conversation = conversations[index];
                          return ListTile(
                            selected: conversation.id == activeConversationId,
                            leading: const Icon(Icons.chat_bubble_outline),
                            title: Text(
                              conversation.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(conversation.modelId),
                            onTap:
                                () => Navigator.pop(context, conversation.id),
                            trailing: IconButton(
                              tooltip: 'Delete conversation',
                              onPressed: () => onDelete(conversation.id),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
