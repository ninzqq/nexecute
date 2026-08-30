import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexecute/ai/application/ai_note_event_prompt.dart';
import 'package:nexecute/ai/domain/ai_event_proposal.dart';
import 'package:nexecute/ai/presentation/ai_note_event_extraction_controller.dart';
import 'package:nexecute/ai/repositories/ai_assistant_repository.dart';
import 'package:nexecute/ai/repositories/ai_connection_profile_store.dart';
import 'package:nexecute/home/bottomsheets/editor_tag_selector.dart';
import 'package:nexecute/home/bottomsheets/event_reminder_field.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/shared/bottom_sheet_safe_area.dart';
import 'package:provider/provider.dart';

Future<AiEventProposalReviewDraft?> showAiNoteEventExtractionPreview(
  BuildContext context, {
  required Quicxec note,
  DateTime Function()? clock,
}) async {
  final controller = AiNoteEventExtractionController(
    assistantRepository: context.read<AiAssistantRepository>(),
    connectionProfileStore: context.read<AiConnectionProfileStore>(),
    clock: clock,
  );
  await controller.initialize();
  if (!context.mounted) {
    controller.dispose();
    return null;
  }
  try {
    return await showModalBottomSheet<AiEventProposalReviewDraft>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (_) => BottomSheetSafeArea(
            child: _AiNoteEventExtractionSheet(
              note: note,
              controller: controller,
            ),
          ),
    );
  } finally {
    controller.dispose();
  }
}

class _AiNoteEventExtractionSheet extends StatefulWidget {
  const _AiNoteEventExtractionSheet({
    required this.note,
    required this.controller,
  });

  final Quicxec note;
  final AiNoteEventExtractionController controller;

  @override
  State<_AiNoteEventExtractionSheet> createState() =>
      _AiNoteEventExtractionSheetState();
}

class _AiNoteEventExtractionSheetState
    extends State<_AiNoteEventExtractionSheet> {
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
        widget.note.title.length > aiMaxEventSourceTitleCharacters ||
        content.length > aiMaxEventSourceContentCharacters;
    final requestPreview =
        sourceTooLarge
            ? null
            : controller.buildPrompt(
              noteTitle: widget.note.title,
              noteContent: content,
            );
    final generating =
        controller.status == AiNoteEventExtractionStatus.generating;
    final completed =
        controller.status == AiNoteEventExtractionStatus.completed;
    final retrying =
        controller.status == AiNoteEventExtractionStatus.failed ||
        controller.status == AiNoteEventExtractionStatus.cancelled;
    final draft = controller.reviewDraft;

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Propose event with AI',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              profile == null
                  ? 'No AI connection selected'
                  : '${profile.name} · ${profile.modelId}',
              key: const Key('ai-note-event-destination'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            const Text(
              'Only the exact note and reference time shown below will be sent to the selected AI endpoint.',
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
                      key: const Key('ai-note-event-technical-preview'),
                      tilePadding: EdgeInsets.zero,
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: const Text('Exact technical request'),
                      subtitle: const Text(
                        'Fixed instructions, reference time, and note JSON',
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
                    'The proposal stays on this device, outside AI chat history and Firestore. The source note is never modified.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (sourceTooLarge) ...[
                    const SizedBox(height: 12),
                    Text(
                      'This note exceeds the event extraction limit and cannot be sent.',
                      key: const Key('ai-note-event-source-too-large'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (controller.errorMessage case final message?) ...[
                    const SizedBox(height: 12),
                    Text(
                      message,
                      key: const Key('ai-note-event-status'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    if (retrying) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Nothing was created. You can retry the request or discard it.',
                        key: Key('ai-note-event-retry-guidance'),
                      ),
                    ],
                  ],
                  if (completed) ...[
                    const SizedBox(height: 16),
                    if (draft == null)
                      const _NoEventProposal()
                    else
                      _EventProposalReview(controller: controller),
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
                    key: const Key('ai-note-event-stop'),
                    onPressed: () => unawaited(controller.cancel()),
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Stop request'),
                  )
                else if (!completed || draft == null)
                  FilledButton.icon(
                    key: const Key('ai-note-event-send'),
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
                      retrying || completed
                          ? Icons.refresh_rounded
                          : Icons.auto_awesome_rounded,
                    ),
                    label: Text(retrying || completed ? 'Retry' : 'Send to AI'),
                  )
                else
                  Tooltip(
                    message:
                        controller.canContinue
                            ? 'No event will be written before Step 10C confirmation.'
                            : draft.validationMessage ?? '',
                    child: FilledButton.icon(
                      key: const Key('ai-note-event-ready'),
                      onPressed:
                          controller.canContinue
                              ? () => Navigator.of(context).pop(draft)
                              : null,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Ready for confirmation'),
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

class _NoEventProposal extends StatelessWidget {
  const _NoEventProposal();

  @override
  Widget build(BuildContext context) {
    return const Column(
      key: Key('ai-note-event-completed'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('No calendar event was found in this note.'),
        SizedBox(height: 6),
        Text('Discard this result or send the note again to retry.'),
      ],
    );
  }
}

class _EventProposalReview extends StatefulWidget {
  const _EventProposalReview({required this.controller});

  final AiNoteEventExtractionController controller;

  @override
  State<_EventProposalReview> createState() => _EventProposalReviewState();
}

class _EventProposalReviewState extends State<_EventProposalReview> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    final draft = widget.controller.reviewDraft!;
    _titleController = TextEditingController(text: draft.title);
    _descriptionController = TextEditingController(text: draft.description);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final draft = controller.reviewDraft!;
    final missing = controller.originallyMissingFields;
    final validationMessage = draft.validationMessage;

    return Column(
      key: const Key('ai-note-event-completed'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Review event proposal',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        const Text(
          'AI-supplied schedule values are suggestions. Verify them and fill every highlighted required field.',
        ),
        const SizedBox(height: 14),
        TextFormField(
          key: const Key('ai-note-event-title'),
          controller: _titleController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
          maxLength: aiMaxProposedEventTitleCharacters,
          onChanged: controller.updateTitle,
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: const Key('ai-note-event-description'),
          controller: _descriptionController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          maxLength: aiMaxProposedEventDescriptionCharacters,
          onChanged: controller.updateDescription,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<bool>(
          key: ValueKey('ai-note-event-all-day-${draft.isAllDay}'),
          initialValue: draft.isAllDay,
          decoration: InputDecoration(
            labelText: 'Event type',
            prefixIcon: const Icon(Icons.event_outlined),
            border: const OutlineInputBorder(),
            errorText:
                draft.isAllDay == null
                    ? 'Required — missing from the note'
                    : null,
            helperText:
                draft.isAllDay != null &&
                        missing.contains(AiEventReviewField.isAllDay)
                    ? 'Missing from the note'
                    : draft.isAllDay == null
                    ? null
                    : 'AI suggestion — verify',
          ),
          items: const [
            DropdownMenuItem(value: false, child: Text('Timed event')),
            DropdownMenuItem(value: true, child: Text('All-day event')),
          ],
          onChanged: (value) {
            if (value != null) controller.updateIsAllDay(value);
          },
        ),
        const SizedBox(height: 10),
        _DateReviewField(
          fieldKey: const Key('ai-note-event-start-date'),
          label: 'Start date',
          value: draft.startDate,
          originallyMissing: missing.contains(AiEventReviewField.startDate),
          onChanged: controller.updateStartDate,
        ),
        const SizedBox(height: 10),
        if (draft.isAllDay != true) ...[
          _TimeReviewField(
            fieldKey: const Key('ai-note-event-start-time'),
            label: 'Start time',
            value: draft.startTime,
            originallyMissing: missing.contains(AiEventReviewField.startTime),
            onChanged: controller.updateStartTime,
          ),
          const SizedBox(height: 10),
        ],
        _DateReviewField(
          fieldKey: const Key('ai-note-event-end-date'),
          label: 'End date',
          value: draft.endDate,
          originallyMissing: missing.contains(AiEventReviewField.endDate),
          onChanged: controller.updateEndDate,
        ),
        const SizedBox(height: 10),
        if (draft.isAllDay != true) ...[
          _TimeReviewField(
            fieldKey: const Key('ai-note-event-end-time'),
            label: 'End time',
            value: draft.endTime,
            originallyMissing: missing.contains(AiEventReviewField.endTime),
            onChanged: controller.updateEndTime,
          ),
          const SizedBox(height: 10),
        ],
        Text('Tags', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        EditorTagSelector(
          selectedTags: draft.tags,
          onTagToggled: controller.toggleTag,
        ),
        const SizedBox(height: 10),
        EventReminderField(
          reminder: draft.reminder,
          onChanged: controller.updateReminder,
        ),
        if (validationMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            validationMessage,
            key: const Key('ai-note-event-validation'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _DateReviewField extends StatelessWidget {
  const _DateReviewField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.originallyMissing,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final DateTime? value;
  final bool originallyMissing;
  final ValueChanged<DateTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: fieldKey,
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          border: const OutlineInputBorder(),
          errorText: value == null ? 'Required — missing from the note' : null,
          helperText:
              value != null && originallyMissing
                  ? 'Missing from the note'
                  : value == null
                  ? null
                  : 'AI suggestion — verify',
        ),
        child: Text(
          value == null
              ? 'Choose date'
              : MaterialLocalizations.of(context).formatMediumDate(value!),
        ),
      ),
    );
  }
}

class _TimeReviewField extends StatelessWidget {
  const _TimeReviewField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.originallyMissing,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final Duration? value;
  final bool originallyMissing;
  final ValueChanged<Duration> onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = TimeOfDay.now();
    final selected = await showTimePicker(
      context: context,
      initialTime:
          value == null
              ? now
              : TimeOfDay(
                hour: value!.inHours,
                minute: value!.inMinutes.remainder(60),
              ),
    );
    if (selected != null) {
      onChanged(Duration(hours: selected.hour, minutes: selected.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final time =
        value == null
            ? null
            : TimeOfDay(
              hour: value!.inHours,
              minute: value!.inMinutes.remainder(60),
            );
    return InkWell(
      key: fieldKey,
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.access_time_outlined),
          border: const OutlineInputBorder(),
          errorText: value == null ? 'Required — missing from the note' : null,
          helperText:
              value != null && originallyMissing
                  ? 'Missing from the note'
                  : value == null
                  ? null
                  : 'AI suggestion — verify',
        ),
        child: Text(
          time == null
              ? 'Choose time'
              : MaterialLocalizations.of(context).formatTimeOfDay(time),
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
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: SelectableText(value),
    );
  }
}
