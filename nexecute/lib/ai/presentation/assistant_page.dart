import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/shared/bottom_sheet_safe_area.dart';
import 'package:provider/provider.dart';

class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  late final AiChatController _controller;
  late final AiApplicationContextReadService _contextReadService;
  final _composerController = TextEditingController();
  final _scrollController = ScrollController();
  final Map<String, AiApplicationContextEnvelope> _noteContexts = {};
  AiApplicationContextEnvelope? _taskContext;
  AiApplicationContextEnvelope? _eventContext;
  DateTime? _contextGeneratedAt;
  bool _isLoadingContext = false;

  @override
  void initState() {
    super.initState();
    _contextReadService = context.read<AiApplicationContextReadService>();
    final assistantRepository = context.read<AiAssistantRepository>();
    _controller = AiChatController(
      assistantRepository: assistantRepository,
      connectionProfileStore: context.read<AiConnectionProfileStore>(),
      conversationStore: context.read<AiConversationStore>(),
      readToolCoordinator: AiReadToolCoordinator(
        assistantRepository: assistantRepository,
        readService: _contextReadService,
      ),
    )..addListener(_onControllerChanged);
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _controller.activeProfile;
    return Scaffold(
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
        actions: [
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
        ],
      ),
      body: SafeArea(
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
            _Composer(
              controller: _composerController,
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
        onAction: () => Navigator.pushNamed(context, '/settings'),
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
    if (!mounted || !sent) return;
    setState(_clearApplicationContext);
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
    required this.enabled,
    required this.isGenerating,
    required this.onSend,
    required this.onStop,
    required this.onAttach,
    required this.isLoadingContext,
  });

  final TextEditingController controller;
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
              child: TextField(
                key: const Key('assistant-composer'),
                controller: controller,
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
  const _MessageBubble({required this.message, this.reasoning, this.onRetry});

  final AiChatMessage message;
  final String? reasoning;
  final VoidCallback? onRetry;

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
              AiDiagnosticPanel(diagnostic: diagnostic, compact: true),
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
