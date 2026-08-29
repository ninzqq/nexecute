import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexecute/ai/application/ai_note_task_prompt.dart';
import 'package:nexecute/ai/domain/ai_task_proposal.dart';
import 'package:nexecute/ai/presentation/ai_note_task_extraction_controller.dart';
import 'package:nexecute/ai/repositories/ai_assistant_repository.dart';
import 'package:nexecute/ai/repositories/ai_connection_profile_store.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:provider/provider.dart';

typedef AiTaskProposalCreateCallback =
    Future<void> Function(List<AiProposedTask> tasks);

Future<void> showAiNoteTaskExtractionPreview(
  BuildContext context, {
  required Quicxec note,
  AiTaskProposalCreateCallback? onCreate,
}) async {
  final controller = AiNoteTaskExtractionController(
    assistantRepository: context.read<AiAssistantRepository>(),
    connectionProfileStore: context.read<AiConnectionProfileStore>(),
  );
  await controller.initialize();
  if (!context.mounted) {
    controller.dispose();
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (_) => _AiNoteTaskExtractionSheet(
          note: note,
          controller: controller,
          onCreate: onCreate,
        ),
  );
  controller.dispose();
}

class _AiNoteTaskExtractionSheet extends StatefulWidget {
  const _AiNoteTaskExtractionSheet({
    required this.note,
    required this.controller,
    this.onCreate,
  });

  final Quicxec note;
  final AiNoteTaskExtractionController controller;
  final AiTaskProposalCreateCallback? onCreate;

  @override
  State<_AiNoteTaskExtractionSheet> createState() =>
      _AiNoteTaskExtractionSheetState();
}

class _AiNoteTaskExtractionSheetState
    extends State<_AiNoteTaskExtractionSheet> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
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
                    'The dedicated extraction instructions are sent separately. The note is not modified, and no tasks are created in this step.',
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
                    _TaskProposalReview(controller: controller),
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
                  child: Text(completed ? 'Discard' : 'Cancel'),
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
                  Tooltip(
                    message:
                        widget.onCreate == null
                            ? 'Task creation will be enabled in Step 7D.'
                            : '',
                    child: FilledButton.icon(
                      key: const Key('ai-note-task-create'),
                      onPressed:
                          controller.selectedTaskCount == 0 ||
                                  widget.onCreate == null
                              ? null
                              : () => unawaited(
                                widget.onCreate!(controller.selectedTasks),
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
}

class _TaskProposalReview extends StatelessWidget {
  const _TaskProposalReview({required this.controller});

  final AiNoteTaskExtractionController controller;

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
              onPressed: () => controller.setAllTasksSelected(true),
              child: const Text('Select all'),
            ),
            TextButton(
              key: const Key('ai-note-task-select-none'),
              onPressed: () => controller.setAllTasksSelected(false),
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
                  (selected) =>
                      controller.setTaskSelected(index, selected ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(items[index].title),
              secondary: IconButton(
                key: Key('ai-note-task-edit-$index'),
                tooltip: 'Edit task',
                onPressed: () => _editTask(context, controller, index),
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
          ),
        ],
        Text(
          'Review is local. No tasks have been created yet.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Creation will be enabled in Step 7D.',
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
