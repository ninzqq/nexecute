import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexecute/home/bottomsheets/item_editor.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/models/event_recurrence.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/shared/bottom_sheet_safe_area.dart';
import 'package:nexecute/shared/adaptive_navigation_shell.dart';
import 'package:nexecute/shared/event_delete_confirmation.dart';
import 'package:nexecute/shared/event_reminder_labels.dart';
import 'package:nexecute/shared/event_recurrence_labels.dart';
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';

Future<void> showEventDetails(BuildContext context, Event event) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: adaptiveSheetConstraints(context),
    builder:
        (_) =>
            BottomSheetSafeArea(child: EventDetailsBottomSheet(event: event)),
  );
}

class EventDetailsBottomSheet extends StatelessWidget {
  final Event event;

  const EventDetailsBottomSheet({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(child: EventDetailsPanel(event: event));
  }
}

class EventDetailsPanel extends StatelessWidget {
  const EventDetailsPanel({
    super.key,
    required this.event,
    this.onClose,
    this.onDeleted,
  });

  final Event event;
  final VoidCallback? onClose;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        key: const Key('event-details-content'),
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, onClose == null ? 4 : 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EventDetailsHeader(event: event, onClose: onClose),
              const SizedBox(height: 16),
              _EventScheduleCard(
                date: _dateLabel(),
                time: _timeLabel(),
                reminder:
                    event.reminder == EventReminder.none
                        ? null
                        : event.reminder.label,
                recurrence:
                    event.recurrence == EventRecurrence.none
                        ? null
                        : event.recurrence.detailsLabel,
              ),
              if (event.description.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                const _SectionHeading(
                  icon: Icons.notes_rounded,
                  label: 'Description',
                ),
                const SizedBox(height: 10),
                _DescriptionCard(description: event.description.trim()),
              ],
              if (event.tags.isNotEmpty) ...[
                const SizedBox(height: 20),
                const _SectionHeading(icon: Icons.sell_outlined, label: 'Tags'),
                const SizedBox(height: 10),
                Wrap(
                  key: const Key('event-details-tags'),
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final tag in event.tags) _TagChip(tag: tag)],
                ),
              ],
              const SizedBox(height: 22),
              _EventDetailsActions(
                onEdit:
                    () =>
                        showItemEditor(context, event: event, isEditing: true),
                onDelete: () => _deleteEvent(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteEvent(BuildContext context) async {
    final confirmed = await confirmEventDeletion(context, event);
    if (!confirmed || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await context.read<EventRepository>().deleteEvent(event);
      if (!context.mounted) return;
      if (onDeleted case final callback?) {
        callback();
      } else {
        navigator.pop();
      }
      messenger.showSnackBar(const SnackBar(content: Text('Event deleted')));
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete event')),
      );
    }
  }

  String _timeLabel() {
    if (event.isAllDay) return 'All day';
    return '${DateFormat('HH:mm').format(event.startTime)}–${DateFormat('HH:mm').format(event.endTime)}';
  }

  String _dateLabel() {
    final start = DateFormat('EEEE, d MMMM yyyy').format(event.startTime);
    final end = DateFormat('EEEE, d MMMM yyyy').format(event.endTime);
    return start == end ? start : '$start – $end';
  }
}

class _EventDetailsHeader extends StatelessWidget {
  const _EventDetailsHeader({required this.event, this.onClose});

  final Event event;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appPalette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: palette.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.event_rounded, color: palette.primary, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              event.title,
              key: const Key('event-details-title'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ),
        if (onClose != null) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Close event details',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ],
    );
  }
}

class _EventScheduleCard extends StatelessWidget {
  const _EventScheduleCard({
    required this.date,
    required this.time,
    this.reminder,
    this.recurrence,
  });

  final String date;
  final String time;
  final String? reminder;
  final String? recurrence;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      key: const Key('event-details-schedule-card'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surfaceRaised.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.outline.withValues(alpha: 0.65)),
      ),
      child: Column(
        children: [
          _ScheduleLine(
            icon: Icons.calendar_today_rounded,
            label: 'Date',
            value: date,
          ),
          const _CardDivider(),
          _ScheduleLine(
            icon: Icons.schedule_rounded,
            label: 'Time',
            value: time,
          ),
          if (reminder != null) ...[
            const _CardDivider(),
            _ScheduleLine(
              icon: Icons.notifications_outlined,
              label: 'Reminder',
              value: reminder!,
            ),
          ],
          if (recurrence != null) ...[
            const _CardDivider(),
            _ScheduleLine(
              icon: Icons.repeat_rounded,
              label: 'Recurrence',
              value: recurrence!,
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleLine extends StatelessWidget {
  const _ScheduleLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appPalette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 19, color: palette.secondary),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.onSurface.withValues(alpha: 0.62),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.25),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 9, 0, 9),
      child: Divider(
        height: 1,
        color: context.appPalette.outline.withValues(alpha: 0.65),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appPalette;

    return Row(
      children: [
        Icon(icon, size: 18, color: palette.secondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: palette.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appPalette;

    return Container(
      key: const Key('event-details-description-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceRaised.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.outline),
      ),
      child: Text(
        description,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Chip(
      avatar: Icon(Icons.tag_rounded, size: 16, color: palette.primary),
      label: Text(tag),
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: palette.outline),
      backgroundColor: palette.surfaceRaised,
    );
  }
}

class _EventDetailsActions extends StatelessWidget {
  const _EventDetailsActions({required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final edit = Tooltip(
      message: 'Edit event',
      child: FilledButton.icon(
        key: const Key('event-details-edit-action'),
        onPressed: onEdit,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Edit event'),
      ),
    );
    final delete = Tooltip(
      message: 'Delete event',
      child: OutlinedButton.icon(
        key: const Key('event-details-delete-action'),
        onPressed: onDelete,
        style: OutlinedButton.styleFrom(
          foregroundColor: error,
          side: BorderSide(color: error.withValues(alpha: 0.65)),
        ),
        icon: const Icon(Icons.delete_outline_rounded),
        label: const Text('Delete event'),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300) {
          return Column(
            key: const Key('event-details-actions'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [edit, const SizedBox(height: 10), delete],
          );
        }
        return Row(
          key: const Key('event-details-actions'),
          children: [
            Expanded(child: edit),
            const SizedBox(width: 12),
            Expanded(child: delete),
          ],
        );
      },
    );
  }
}
