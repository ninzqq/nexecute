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
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onResize,
    required this.onResizeEnd,
    required this.onEventSelected,
    this.reserveFloatingActionButtonSpace = true,
  });

  final DateTime day;
  final List<Event> events;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;
  final ValueChanged<double>? onResize;
  final ValueChanged<double>? onResizeEnd;
  final ValueChanged<Event> onEventSelected;
  final bool reserveFloatingActionButtonSpace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appPalette;
    final fabClearance =
        reserveFloatingActionButtonSpace
            ? math.min(88.0, MediaQuery.sizeOf(context).width * 0.25)
            : 8.0;

    return ColoredBox(
      key: const Key('selected-day-agenda'),
      color: palette.chrome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AgendaHeader(
            day: day,
            eventCount: events.length,
            isExpanded: isExpanded,
            onToggleExpanded: onToggleExpanded,
            onResize: onResize,
            onResizeEnd: onResizeEnd,
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

class _AgendaHeader extends StatelessWidget {
  const _AgendaHeader({
    required this.day,
    required this.eventCount,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onResize,
    required this.onResizeEnd,
  });

  final DateTime day;
  final int eventCount;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;
  final ValueChanged<double>? onResize;
  final ValueChanged<double>? onResizeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appPalette;
    final canExpand = onToggleExpanded != null;
    final tooltip = isExpanded ? 'Collapse events' : 'Expand events';

    return Tooltip(
      message: canExpand ? '$tooltip · drag to resize' : '',
      child: Semantics(
        button: canExpand,
        label: canExpand ? tooltip : null,
        value: canExpand ? (isExpanded ? 'Expanded' : 'Collapsed') : null,
        onTap: onToggleExpanded,
        child: GestureDetector(
          key: const Key('agenda-resize-handle'),
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onToggleExpanded,
          onVerticalDragUpdate:
              onResize == null
                  ? null
                  : (details) => onResize!(details.primaryDelta ?? 0),
          onVerticalDragEnd:
              onResizeEnd == null
                  ? null
                  : (details) => onResizeEnd!(details.primaryVelocity ?? 0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 5, 8, 6),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: isExpanded ? 42 : 34,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.onSurface.withValues(
                      alpha: canExpand ? 0.38 : 0.16,
                    ),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
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
                      '$eventCount ${eventCount == 1 ? 'event' : 'events'}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: palette.secondary,
                      ),
                    ),
                    if (canExpand) ...[
                      const SizedBox(width: 2),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          size: 22,
                          color: palette.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
