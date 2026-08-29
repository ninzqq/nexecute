import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexecute/ai/application/ai_note_task_prompt.dart';
import 'package:nexecute/ai/domain/ai_task_proposal.dart';
import 'package:nexecute/ai/presentation/ai_note_task_extraction_controller.dart';
import 'package:nexecute/ai/presentation/ai_task_proposal_creation_controller.dart';
import 'package:nexecute/ai/repositories/ai_assistant_repository.dart';
import 'package:nexecute/ai/repositories/ai_connection_profile_store.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/repositories/todo_repository.dart';
import 'package:provider/provider.dart';

typedef AiTaskProposalCreateCallback =
    Future<void> Function(CreateTodosCommand command);

Future<int?> showAiNoteTaskExtractionPreview(
  BuildContext context, {
  required Quicxec note,
  AiTaskProposalCreateCallback? onCreate,
  String Function()? creationIdFactory,
  DateTime Function()? clock,
}) async {
  final extractionController = AiNoteTaskExtractionController(
    assistantRepository: context.read<AiAssistantRepository>(),
    connectionProfileStore: context.read<AiConnectionProfileStore>(),
  );
  final creationController =
      onCreate == null
          ? null
          : AiTaskProposalCreationController(
            submit: onCreate,
            idFactory: creationIdFactory,
            clock: clock,
          );
  await extractionController.initialize();
  if (!context.mounted) {
    extractionController.dispose();
    creationController?.dispose();
    return null;
  }
  try {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (_) => _AiNoteTaskExtractionSheet(
            note: note,
            extractionController: extractionController,
            creationController: creationController,
          ),
    );
    if (creationController?.status == AiTaskProposalCreationStatus.completed) {
      return creationController!.command!.titles.length;
    }
    return null;
  } finally {
    extractionController.dispose();
    creationController?.dispose();
  }
}

class _AiNoteTaskExtractionSheet extends StatefulWidget {
  const _AiNoteTaskExtractionSheet({
    required this.note,
    required this.extractionController,
    required this.creationController,
  });

  final Quicxec note;
  final AiNoteTaskExtractionController extractionController;
  final AiTaskProposalCreationController? creationController;

  @override
  State<_AiNoteTaskExtractionSheet> createState() =>
      _AiNoteTaskExtractionSheetState();
}

class _AiNoteTaskExtractionSheetState
    extends State<_AiNoteTaskExtractionSheet> {
  @override
  void initState() {
    super.initState();
    widget.extractionController.addListener(_refresh);
    widget.creationController?.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.extractionController.removeListener(_refresh);
    widget.creationController?.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.extractionController;
    final creationController = widget.creationController;
    final profile = controller.activeProfile;
    final content = widget.note.contentAsPlainText;
    final sourceTooLarge =
        widget.note.title.length > aiMaxTaskSourceTitleCharacters ||
        content.length > aiMaxTaskSourceContentCharacters;
    final requestPreview =
        sourceTooLarge
            ? null
            : AiNoteTaskPromptBuilder.build(
              noteTitle: widget.note.title,
              noteContent: content,
            );
    final generating =
        controller.status == AiNoteTaskExtractionStatus.generating;
    final completed = controller.status == AiNoteTaskExtractionStatus.completed;
    final retrying =
        controller.status == AiNoteTaskExtractionStatus.failed ||
        controller.status == AiNoteTaskExtractionStatus.cancelled;
    final creationStatus = creationController?.status;
    final creationStarted = creationController?.command != null;
    final creating = creationStatus == AiTaskProposalCreationStatus.creating;
    final creationFailed =
        creationStatus == AiTaskProposalCreationStatus.failed;
    final creationCompleted =
        creationStatus == AiTaskProposalCreationStatus.completed;

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Propose tasks with AI',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              profile == null
                  ? 'No AI connection selected'
                  : '${profile.name} · ${profile.modelId}',
              key: const Key('ai-note-task-destination'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            const Text(
              'Only the exact note data shown below will be sent to the selected AI endpoint.',
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  _PreviewField(
                    label: 'Note title',
                    value:
                        widget.note.title.isEmpty
                            ? '(No title)'
                            : widget.note.title,
                  ),
                  const SizedBox(height: 12),
                  _PreviewField(
                    label: 'Note content',
                    value: content.isEmpty ? '(Empty note)' : content,
                  ),
                  const SizedBox(height: 12),
                  if (requestPreview != null)
                    ExpansionTile(
                      key: const Key('ai-note-task-technical-preview'),
                      tilePadding: EdgeInsets.zero,
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: const Text('Exact technical request'),
                      subtitle: const Text(
                        'Fixed instructions and JSON message',
                      ),
                      children: [
                        _PreviewField(
                          label: 'System instruction',
                          value: requestPreview.systemInstruction,
                        ),
                        const SizedBox(height: 12),
                        _PreviewField(
                          label: 'User message',
                          value: requestPreview.userMessage,
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'The dedicated extraction instructions are sent separately. The source note is never modified, and tasks are created only after final confirmation.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (sourceTooLarge) ...[
                    const SizedBox(height: 12),
                    Text(
                      'This note exceeds the extraction limit and cannot be sent.',
                      key: const Key('ai-note-task-source-too-large'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (controller.errorMessage case final message?) ...[
                    const SizedBox(height: 12),
                    Text(
                      message,
                      key: const Key('ai-note-task-status'),
                      style: TextStyle(
                        color:
                            completed
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error,
                      ),
                    ),
                    if (retrying) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Nothing was created. You can retry the request or cancel.',
                        key: Key('ai-note-task-retry-guidance'),
                      ),
                    ],
                  ],
                  if (completed) ...[
                    const SizedBox(height: 12),
                    _TaskProposalReview(
                      controller: controller,
                      enabled: !creationStarted,
                    ),
                    if (creationStarted) ...[
                      const SizedBox(height: 12),
                      _CreationStatus(controller: creationController!),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      generating ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    completed
                        ? creationStarted
                            ? 'Close'
                            : 'Discard'
                        : 'Cancel',
                  ),
                ),
                const SizedBox(width: 8),
                if (generating)
                  OutlinedButton.icon(
                    key: const Key('ai-note-task-stop'),
                    onPressed: () => unawaited(controller.cancel()),
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Stop request'),
                  )
                else if (!completed)
                  FilledButton.icon(
                    key: const Key('ai-note-task-send'),
                    onPressed:
                        profile == null || sourceTooLarge
                            ? null
                            : () => unawaited(
                              controller.start(
                                noteId: widget.note.id,
                                noteTitle: widget.note.title,
                                noteContent: content,
                              ),
                            ),
                    icon: Icon(
                      retrying
                          ? Icons.refresh_rounded
                          : Icons.auto_awesome_rounded,
                    ),
                    label: Text(retrying ? 'Retry' : 'Send to AI'),
                  )
                else if (controller.reviewItems.isEmpty)
                  FilledButton.icon(
                    key: const Key('ai-note-task-send'),
                    onPressed:
                        profile == null || sourceTooLarge
                            ? null
                            : () => unawaited(
                              controller.start(
                                noteId: widget.note.id,
                                noteTitle: widget.note.title,
                                noteContent: content,
                              ),
                            ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  )
                else if (controller.reviewItems.isNotEmpty)
                  if (creating)
                    FilledButton.icon(
                      key: const Key('ai-note-task-creating'),
                      onPressed: null,
                      icon: const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      label: const Text('Creating tasks...'),
                    )
                  else if (creationFailed)
                    FilledButton.icon(
                      key: const Key('ai-note-task-retry-create'),
                      onPressed: () => unawaited(creationController!.retry()),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry same creation'),
                    )
                  else if (!creationCompleted)
                    Tooltip(
                      message:
                          creationController == null
                              ? 'Task creation is not configured.'
                              : '',
                      child: FilledButton.icon(
                        key: const Key('ai-note-task-create'),
                        onPressed:
                            controller.selectedTaskCount == 0 ||
                                    creationController == null
                                ? null
                                : () => unawaited(
                                  _confirmAndCreate(
                                    context,
                                    extractionController: controller,
                                    creationController: creationController,
                                  ),
                                ),
                        icon: const Icon(Icons.add_task_rounded),
                        label: Text(
                          'Create selected (${controller.selectedTaskCount})',
                        ),
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndCreate(
    BuildContext context, {
    required AiNoteTaskExtractionController extractionController,
    required AiTaskProposalCreationController creationController,
  }) async {
    final titles = [
      for (final task in extractionController.selectedTasks) task.title,
    ];
    if (titles.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              'Create ${titles.length} task${titles.length == 1 ? '' : 's'}?',
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('These exact task titles will be created:'),
                  const SizedBox(height: 12),
                  for (final title in titles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  '),
                          Expanded(child: Text(title)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  const Text(
                    'The source note will remain unchanged.',
                    key: Key('ai-note-task-preserve-note'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Back'),
              ),
              FilledButton.icon(
                key: const Key('ai-note-task-confirm-create'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(Icons.add_task_rounded),
                label: Text(
                  'Create ${titles.length} task${titles.length == 1 ? '' : 's'}',
                ),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    await creationController.create(
      sourceNoteId: widget.note.id,
      titles: titles,
    );
  }
}

class _TaskProposalReview extends StatelessWidget {
  const _TaskProposalReview({required this.controller, required this.enabled});

  final AiNoteTaskExtractionController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final items = controller.reviewItems;
    if (items.isEmpty) {
      return const Column(
        key: Key('ai-note-task-completed'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No task proposals were found.'),
          SizedBox(height: 6),
          Text('Discard this result or send the note again to retry.'),
        ],
      );
    }

    return Column(
      key: const Key('ai-note-task-completed'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${items.length} task proposal${items.length == 1 ? '' : 's'} received',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton(
              key: const Key('ai-note-task-select-all'),
              onPressed:
                  enabled ? () => controller.setAllTasksSelected(true) : null,
              child: const Text('Select all'),
            ),
            TextButton(
              key: const Key('ai-note-task-select-none'),
              onPressed:
                  enabled ? () => controller.setAllTasksSelected(false) : null,
              child: const Text('None'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (var index = 0; index < items.length; index++) ...[
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: CheckboxListTile(
              key: Key('ai-note-task-review-$index'),
              value: items[index].selected,
              onChanged:
                  enabled
                      ? (selected) =>
                          controller.setTaskSelected(index, selected ?? false)
                      : null,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(items[index].title),
              secondary: IconButton(
                key: Key('ai-note-task-edit-$index'),
                tooltip: 'Edit task',
                onPressed:
                    enabled
                        ? () => _editTask(context, controller, index)
                        : null,
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
          ),
        ],
        Text(
          enabled
              ? 'Review is local. No tasks have been created yet.'
              : 'The reviewed titles are locked to the submitted creation.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          enabled
              ? 'Select the tasks you want to create.'
              : 'The confirmed selection is frozen for safe retries.',
          key: const Key('ai-note-task-create-pending'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _editTask(
    BuildContext context,
    AiNoteTaskExtractionController controller,
    int index,
  ) async {
    final formKey = GlobalKey<FormState>();
    var editedTitle = controller.reviewItems[index].title;
    final updatedTitle = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Edit proposed task'),
            content: Form(
              key: formKey,
              child: TextFormField(
                key: const Key('ai-note-task-edit-field'),
                initialValue: editedTitle,
                autofocus: true,
                maxLength: aiMaxProposedTaskTitleCharacters,
                maxLines: 1,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Task title'),
                validator:
                    (value) => controller.validateTaskTitle(
                      value ?? '',
                      editingIndex: index,
                    ),
                onChanged: (value) => editedTitle = value,
                onFieldSubmitted: (_) {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(dialogContext).pop(editedTitle);
                  }
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('ai-note-task-save-edit'),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(dialogContext).pop(editedTitle);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
    if (updatedTitle != null) controller.updateTaskTitle(index, updatedTitle);
  }
}

class _CreationStatus extends StatelessWidget {
  const _CreationStatus({required this.controller});

  final AiTaskProposalCreationController controller;

  @override
  Widget build(BuildContext context) {
    final command = controller.command!;
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, title, message, color) = switch (controller.status) {
      AiTaskProposalCreationStatus.ready => (
        Icons.info_outline_rounded,
        'Ready',
        '',
        colorScheme.primary,
      ),
      AiTaskProposalCreationStatus.creating => (
        Icons.cloud_upload_outlined,
        'Creating ${command.titles.length} tasks',
        'The confirmed selection is being written atomically. Closing this window will not cancel the submitted write.',
        colorScheme.primary,
      ),
      AiTaskProposalCreationStatus.failed => (
        Icons.error_outline_rounded,
        'Creation not confirmed',
        controller.errorMessage!,
        colorScheme.error,
      ),
      AiTaskProposalCreationStatus.completed => (
        Icons.check_circle_outline_rounded,
        '${command.titles.length} task${command.titles.length == 1 ? '' : 's'} created',
        'The source note was not changed.',
        colorScheme.primary,
      ),
    };

    return DecoratedBox(
      key: const Key('ai-note-task-creation-status'),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(message),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewField extends StatelessWidget {
  const _PreviewField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            SelectableText(value),
          ],
        ),
      ),
    );
  }
}
