import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/themes.dart';
import 'package:nexecute/ui/calendar/event_date_utils.dart';

double selectedDayAgendaHeight(int eventCount) {
  if (eventCount == 0) return 120;
  return math.min(232, math.max(120, 42 + eventCount * 54)).toDouble();
}

class SelectedDayAgenda extends StatelessWidget {
  const SelectedDayAgenda({
    super.key,
    required this.day,
    required this.events,
    required this.onEventSelected,
  });

  final DateTime day;
  final List<Event> events;
  final ValueChanged<Event> onEventSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appPalette;
    final fabClearance = math.min(
      88.0,
      MediaQuery.sizeOf(context).width * 0.25,
    );

    return ColoredBox(
      key: const Key('selected-day-agenda'),
      color: palette.chrome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Row(
              children: [
                Icon(
                  Icons.event_note_rounded,
                  size: 18,
                  color: palette.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('EEEE, d MMMM').format(day),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${events.length} ${events.length == 1 ? 'event' : 'events'}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: palette.secondary,
                  ),
                ),
              ],
            ),
          ),
          if (events.isEmpty)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: fabClearance),
                child: Center(
                  child: Text(
                    'No events for this day',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(8, 0, fabClearance, 8),
                itemCount: events.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return Material(
                    color: palette.surfaceRaised,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      key: ValueKey('agenda-event-${event.id}'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onEventSelected(event),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 72,
                              child: Text(
                                _timeLabel(event, day),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: palette.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                event.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: palette.onSurface.withValues(alpha: 0.55),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _timeLabel(Event event, DateTime selectedDay) {
    if (event.isAllDay) return 'All day';
    if (!isSameCalendarDay(event.startTime, selectedDay)) return 'Continues';
    return DateFormat('HH:mm').format(event.startTime);
  }
}
