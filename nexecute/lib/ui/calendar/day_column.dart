import 'package:flutter/material.dart';
import '../../domain/calendar/calendar_day.dart';
import 'package:intl/intl.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/themes.dart';
import 'package:nexecute/ui/calendar/event_date_utils.dart';

class DayColumn extends StatelessWidget {
  final CalendarDay day;
  final List<Event> events;
  final bool isSelected;
  final VoidCallback onSelected;
  final ValueChanged<Event> onEventSelected;

  const DayColumn({
    super.key,
    required this.day,
    required this.events,
    required this.isSelected,
    required this.onSelected,
    required this.onEventSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isWeekend = day.isWeekend;
    final dateLabel = DateFormat('EEE d').format(day.date);
    final palette = context.appPalette;

    return Material(
      color:
          isSelected
              ? palette.primary.withValues(alpha: 0.08)
              : Colors.transparent,
      child: InkWell(
        onTap: onSelected,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Column(
            children: [
              ColoredBox(
                color:
                    isSelected
                        ? palette.primary.withValues(alpha: 0.18)
                        : Theme.of(context).colorScheme.surface,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  child: Text(
                    dateLabel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isWeekend ? palette.secondary : palette.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 600),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(3, 6, 3, 12),
                  child: Column(
                    children: [
                      for (var index = 0; index < events.length; index++) ...[
                        _WeekEventCard(
                          event: events[index],
                          day: day.date,
                          onTap: () => onEventSelected(events[index]),
                        ),
                        if (index < events.length - 1)
                          const SizedBox(height: 4),
                      ],
                    ],
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

class _WeekEventCard extends StatelessWidget {
  const _WeekEventCard({
    required this.event,
    required this.day,
    required this.onTap,
  });

  final Event event;
  final DateTime day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final timeLabel =
        event.isAllDay
            ? 'All day'
            : isSameCalendarDay(event.startTime, day)
            ? DateFormat('HH:mm').format(event.startTime)
            : 'Continues';

    return Material(
      color: palette.primary.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: palette.primary, width: 2)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                timeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: palette.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
