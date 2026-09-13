import 'package:flutter/material.dart';
import 'package:nexecute/ai/application/ai_conversation_note_prompt.dart';
import 'package:nexecute/ai/application/ai_conversation_note_source.dart';
import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/ai/presentation/ai_conversation_note_generation_controller.dart';
import 'package:nexecute/ai/presentation/ai_conversation_note_creation_controller.dart';
import 'package:nexecute/ai/presentation/ai_diagnostic_panel.dart';
import 'package:nexecute/ai/presentation/ai_generation_progress.dart';
import 'package:nexecute/ai/repositories/ai_assistant_repository.dart';
import 'package:nexecute/ai/repositories/ai_connection_profile_store.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/repositories/commands/create_conversation_note_command.dart';
import 'package:nexecute/shared/adaptive_navigation_shell.dart';
import 'package:nexecute/shared/bottom_sheet_safe_area.dart';
import 'package:provider/provider.dart';

Future<Quicxec?> showAiConversationNoteSourcePreview(
  BuildContext context, {
  required AiConversationNoteSource source,
  required AiConnectionProfile profile,
  AiConversationNoteCreateCallback? onCreate,
  String Function()? creationIdFactory,
  DateTime Function()? clock,
}) => showModalBottomSheet<Quicxec>(
  context: context,
  isScrollControlled: true,
  isDismissible: false,
  enableDrag: false,
  showDragHandle: true,
  constraints: adaptiveSheetConstraints(context),
  builder:
      (_) => BottomSheetSafeArea(
        child: _AiConversationNoteSourceSheet(
          source: source,
          profile: profile,
          onCreate: onCreate,
          creationIdFactory: creationIdFactory,
          clock: clock,
        ),
      ),
);

class _AiConversationNoteSourceSheet extends StatefulWidget {
  const _AiConversationNoteSourceSheet({
    required this.source,
    required this.profile,
    this.onCreate,
    this.creationIdFactory,
    this.clock,
  });

  final AiConversationNoteSource source;
  final AiConnectionProfile profile;
  final AiConversationNoteCreateCallback? onCreate;
  final String Function()? creationIdFactory;
  final DateTime Function()? clock;

  @override
  State<_AiConversationNoteSourceSheet> createState() =>
      _AiConversationNoteSourceSheetState();
}

class _AiConversationNoteSourceSheetState
    extends State<_AiConversationNoteSourceSheet> {
  late AiConversationNoteSource _source = widget.source;
  late final AiConversationNoteGenerationController _controller;
  AiConversationNoteCreationController? _creationController;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  Object? _reviewedProposal;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _controller = AiConversationNoteGenerationController(
      assistantRepository: context.read<AiAssistantRepository>(),
      connectionProfileStore: context.read<AiConnectionProfileStore>(),
      previewedProfile: widget.profile,
    )..addListener(_refresh);
    if (widget.onCreate case final onCreate?) {
      _creationController = AiConversationNoteCreationController(
        submit: onCreate,
        idFactory: widget.creationIdFactory,
        clock: widget.clock,
      )..addListener(_refresh);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    _creationController?.removeListener(_refresh);
    _creationController?.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    if (!identical(_reviewedProposal, _controller.proposal)) {
      _reviewedProposal = _controller.proposal;
      _titleController.text = _controller.proposal?.note?.title ?? '';
      _bodyController.text = _controller.proposal?.note?.body ?? '';
    }
    setState(() {});
  }

  AiConversationNoteReviewDraft get _draft => AiConversationNoteReviewDraft(
    title: _titleController.text,
    body: _bodyController.text,
  );

  Future<void> _confirmSave() async {
    final creationController = _creationController;
    final draft = AiConversationNoteReviewDraft(
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
    );
    final source = _source;
    if (creationController == null ||
        creationController.command != null ||
        _isConfirming ||
        !draft.isComplete) {
      return;
    }
    _isConfirming = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Create this note?'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${source.selectedCount} conversation messages'),
                    const SizedBox(height: 12),
                    SelectableText(
                      draft.title,
                      style: Theme.of(dialogContext).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(draft.body),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Back to review'),
              ),
              FilledButton(
                key: const Key('conversation-note-confirm-save'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Create note'),
              ),
            ],
          ),
    );
    _isConfirming = false;
    if (confirmed != true || !mounted) return;
    await creationController.create(source: source, draft: draft);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    String formatTime(DateTime value) {
      final local = value.toLocal();
      return '${localizations.formatMediumDate(local)} '
          '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
    }

    final payload = _source.payload;
    final prompt =
        _source.isWithinLimit
            ? AiConversationNotePromptBuilder.build(_source)
            : null;
    final generating =
        _controller.status == AiConversationNoteGenerationStatus.generating;
    final completed =
        _controller.status == AiConversationNoteGenerationStatus.completed;
    final creationStatus = _creationController?.status;
    final creationStarted = _creationController?.command != null;
    final creating =
        creationStatus == AiConversationNoteCreationStatus.creating;
    final creationFailed =
        creationStatus == AiConversationNoteCreationStatus.failed;
    final creationCompleted =
        creationStatus == AiConversationNoteCreationStatus.completed;
    final draft = _draft;
    return PopScope(
      canPop: !creating,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              Text(
                'Create note from conversation',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Source preview · ${widget.profile.name} · '
                '${widget.profile.modelId}',
                key: const Key('conversation-note-connection'),
              ),
              const SizedBox(height: 8),
              Text(
                '${_source.selectedCount} messages selected · '
                '${_source.olderOmittedCount} older messages omitted',
                key: const Key('conversation-note-counts'),
              ),
              if (_source.startIndex > 0 || _source.newerOmittedCount > 0)
                Text(
                  '${_source.startIndex} more before selection · '
                  '${_source.newerOmittedCount} after selection',
                  key: const Key('conversation-note-selection-omissions'),
                ),
              Text(
                '${formatTime(_source.firstMessageAt)} – '
                '${formatTime(_source.lastMessageAt)}',
                key: const Key('conversation-note-time-range'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: const Key('conversation-note-start'),
                      initialValue: _source.startIndex,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Start at'),
                      items: [
                        for (final index in _source.startOptions)
                          DropdownMenuItem(
                            value: index,
                            child: Text(
                              'Message ${index + 1} · '
                              '${formatTime(_source.availableMessages[index].createdAt)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged:
                          generating || creationStarted
                              ? null
                              : (index) {
                                if (index == null) return;
                                setState(() {
                                  _source = _source.selectRange(
                                    startIndex: index,
                                    endIndex: _source.endIndex,
                                  );
                                });
                                _controller.reset();
                              },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: const Key('conversation-note-end'),
                      initialValue: _source.endIndex,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Through'),
                      items: [
                        for (final index in _source.endOptions)
                          DropdownMenuItem(
                            value: index,
                            child: Text(
                              'Message ${index + 1} · '
                              '${formatTime(_source.availableMessages[index].createdAt)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged:
                          generating || creationStarted
                              ? null
                              : (index) {
                                if (index == null) return;
                                setState(() {
                                  _source = _source.selectRange(
                                    startIndex: _source.startIndex,
                                    endIndex: index,
                                  );
                                });
                                _controller.reset();
                              },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!_source.isWithinLimit)
                Text(
                  'This source is ${payload.length} characters; the limit is '
                  '$aiMaxConversationNoteSourceCharacters. Select fewer turns '
                  'before generating a note.',
                  key: const Key('conversation-note-over-limit'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 8),
              const Text(
                'This is the exact conversation data sent with a separate note '
                'instruction. Earlier messages, temporary attachments, tool '
                'results, and reasoning are not included. Generating a proposal '
                'does not save it.',
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      payload,
                      key: const Key('conversation-note-payload'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (prompt != null)
                ExpansionTile(
                  key: const Key('conversation-note-technical-preview'),
                  tilePadding: EdgeInsets.zero,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: const Text('Exact technical request'),
                  subtitle: const Text('Fixed instruction and JSON message'),
                  children: [
                    SelectableText(
                      prompt.systemInstruction,
                      key: const Key('conversation-note-system-instruction'),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      prompt.userMessage,
                      key: const Key('conversation-note-user-message'),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              if (generating) ...[
                AiGenerationProgress(
                  reasoning: _controller.reasoning,
                  keyPrefix: 'conversation-note',
                ),
                const SizedBox(height: 12),
              ],
              if (_controller.diagnostic case final diagnostic?) ...[
                AiDiagnosticPanel(
                  diagnostic: diagnostic,
                  onAction: () => Navigator.pushNamed(context, '/settings'),
                ),
                const SizedBox(height: 12),
              ] else if (_controller.errorMessage case final message?) ...[
                Text(
                  message,
                  key: const Key('conversation-note-status'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              if (completed) ...[
                if (_controller.proposal?.note != null) ...[
                  Text(
                    'Unsaved note proposal',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    key: const Key('conversation-note-proposed-title'),
                    enabled: !creationStarted,
                    maxLines: 1,
                    maxLength: maxCreateConversationNoteTitleCharacters,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Note title'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bodyController,
                    key: const Key('conversation-note-proposed-body'),
                    enabled: !creationStarted,
                    minLines: 5,
                    maxLines: 12,
                    maxLength: maxCreateConversationNoteBodyCharacters,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Note text'),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (!draft.isComplete)
                    Text(
                      draft.validationMessage!,
                      key: const Key('conversation-note-review-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ] else
                  const Text(
                    'The model found no useful note to propose.',
                    key: Key('conversation-note-empty-proposal'),
                  ),
                const SizedBox(height: 12),
              ],
              if (creating) ...[
                const Row(
                  children: [
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Creating note…'),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (_creationController?.errorMessage case final message?) ...[
                Text(
                  message,
                  key: const Key('conversation-note-create-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              if (creationCompleted) ...[
                Text(
                  'Note created: ${_creationController!.createdNote!.title}',
                  key: const Key('conversation-note-created'),
                ),
                const SizedBox(height: 12),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      key: const Key('conversation-note-close'),
                      onPressed: creating ? null : () => Navigator.pop(context),
                      child: Text(
                        completed && !creationStarted ? 'Discard' : 'Close',
                      ),
                    ),
                    if (generating)
                      OutlinedButton(
                        key: const Key('conversation-note-cancel'),
                        onPressed: _controller.cancel,
                        child: const Text('Cancel generation'),
                      )
                    else if (!creationStarted)
                      FilledButton(
                        key: const Key('conversation-note-generate'),
                        onPressed:
                            _source.isWithinLimit
                                ? () => _controller.start(_source)
                                : null,
                        child: Text(completed ? 'Regenerate' : 'Generate note'),
                      ),
                    if (completed &&
                        _controller.proposal?.note != null &&
                        _creationController != null &&
                        !creationStarted)
                      FilledButton(
                        key: const Key('conversation-note-save'),
                        onPressed: draft.isComplete ? _confirmSave : null,
                        child: const Text('Save note'),
                      ),
                    if (creationFailed)
                      FilledButton(
                        key: const Key('conversation-note-retry-save'),
                        onPressed: _creationController!.retry,
                        child: const Text('Retry save'),
                      ),
                    if (creationCompleted)
                      FilledButton(
                        key: const Key('conversation-note-open'),
                        onPressed:
                            () => Navigator.pop(
                              context,
                              _creationController!.createdNote,
                            ),
                        child: const Text('Open note'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
