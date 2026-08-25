import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexecute/home/bottomsheets/item_editor.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';

Future<void> showEventDetails(BuildContext context, Event event) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => EventDetailsBottomSheet(event: event),
  );
}

class EventDetailsBottomSheet extends StatelessWidget {
  final Event event;

  const EventDetailsBottomSheet({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appPalette;
    final minimumSheetHeight = MediaQuery.sizeOf(context).height * 0.45;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minimumSheetHeight),
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(event.title, style: theme.textTheme.titleLarge),
                  ),
                  IconButton(
                    tooltip: 'Edit event',
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () {
                      showItemEditor(context, event: event, isEditing: true);
                    },
                  ),
                  IconButton(
                    tooltip: 'Delete event',
                    color: theme.colorScheme.error,
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _deleteEvent(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailRow(icon: Icons.schedule_rounded, text: _timeLabel()),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.calendar_today_rounded,
                text: _dateLabel(),
              ),
              if (event.description.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Description',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: palette.secondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(event.description, style: theme.textTheme.bodyMedium),
              ],
              if (event.tags.isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in event.tags)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(tag),
                      ),
                  ],
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteEvent(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await context.read<EventRepository>().deleteEvent(event);
      if (!context.mounted) return;
      navigator.pop();
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: context.appPalette.secondary),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}
