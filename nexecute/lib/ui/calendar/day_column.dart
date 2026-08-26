import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexecute/domain/calendar/calendar_day.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/themes.dart';
import 'package:nexecute/ui/calendar/event_date_utils.dart';

const weekHourHeight = 56.0;
const weekTimeGridHeight = weekHourHeight * 24;

class DayColumn extends StatelessWidget {
  const DayColumn({
    super.key,
    required this.day,
    required this.events,
    required this.isSelected,
    required this.onSelected,
    required this.onEventSelected,
    this.hourHeight = weekHourHeight,
  });

  final CalendarDay day;
  final List<Event> events;
  final bool isSelected;
  final VoidCallback onSelected;
  final ValueChanged<Event> onEventSelected;
  final double hourHeight;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final gridHeight = hourHeight * 24;
    final placements = _placeTimedEvents(
      events,
      day.date,
      hourHeight: hourHeight,
      gridHeight: gridHeight,
    );

    return SizedBox(
      height: gridHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Material(
                  color:
                      isSelected
                          ? palette.primary.withValues(alpha: 0.08)
                          : Colors.transparent,
                  child: InkWell(
                    key: ValueKey(
                      'week-event-area-${day.date.year}-${day.date.month}-${day.date.day}',
                    ),
                    onTap: onSelected,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: palette.outline),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              for (var hour = 0; hour < 24; hour++)
                Positioned(
                  top: hour * hourHeight,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: palette.outline.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              for (final placement in placements)
                Positioned(
                  top: placement.top,
                  height: placement.height,
                  left:
                      placement.lane /
                          placement.laneCount *
                          constraints.maxWidth +
                      2,
                  right:
                      (placement.laneCount - placement.lane - 1) /
                          placement.laneCount *
                          constraints.maxWidth +
                      2,
                  child: _WeekEventCard(
                    event: placement.event,
                    day: day.date,
                    onTap: () => onEventSelected(placement.event),
                  ),
                ),
            ],
          );
        },
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
    final startsToday = isSameCalendarDay(event.startTime, day);
    final timeLabel =
        startsToday ? DateFormat('HH:mm').format(event.startTime) : 'Continues';

    return Semantics(
      button: true,
      label: '${event.title}, $timeLabel',
      child: Material(
        key: ValueKey(
          'week-event-${event.id}-${day.year}-${day.month}-${day.day}',
        ),
        color: palette.primary.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(4),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showTitle = constraints.maxHeight >= 16;
              final showTime = constraints.maxHeight >= 34;
              return Container(
                padding:
                    showTitle
                        ? const EdgeInsets.fromLTRB(4, 3, 2, 2)
                        : EdgeInsets.zero,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: palette.primary, width: 2),
                  ),
                ),
                child:
                    showTitle
                        ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              maxLines: constraints.maxHeight >= 48 ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(
                                color: palette.onSurface,
                                fontWeight: FontWeight.w600,
                                height: 1.05,
                              ),
                            ),
                            if (showTime) ...[
                              if (event.title.isNotEmpty)
                                const SizedBox(height: 1),
                              Text(
                                timeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: Theme.of(
                                  context,
                                ).textTheme.labelSmall?.copyWith(
                                  color: palette.secondary,
                                  fontSize: 9,
                                  height: 1,
                                ),
                              ),
                            ],
                          ],
                        )
                        : null,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TimedEventSegment {
  const _TimedEventSegment({
    required this.event,
    required this.startMinute,
    required this.endMinute,
  });

  final Event event;
  final double startMinute;
  final double endMinute;
}

class _WeekEventPlacement {
  const _WeekEventPlacement({
    required this.event,
    required this.top,
    required this.height,
    required this.lane,
    required this.laneCount,
  });

  final Event event;
  final double top;
  final double height;
  final int lane;
  final int laneCount;
}

List<_WeekEventPlacement> _placeTimedEvents(
  Iterable<Event> events,
  DateTime day, {
  required double hourHeight,
  required double gridHeight,
}) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = DateTime(day.year, day.month, day.day + 1);
  final segments = <_TimedEventSegment>[];

  for (final event in events) {
    if (event.isAllDay ||
        !event.startTime.isBefore(dayEnd) ||
        !event.endTime.isAfter(dayStart)) {
      continue;
    }

    final startsBeforeDay = !event.startTime.isAfter(dayStart);
    final endsAfterDay = !event.endTime.isBefore(dayEnd);
    final startMinute = startsBeforeDay ? 0.0 : _minuteOfDay(event.startTime);
    final endMinute = endsAfterDay ? 1440.0 : _minuteOfDay(event.endTime);
    if (endMinute <= startMinute) continue;

    segments.add(
      _TimedEventSegment(
        event: event,
        startMinute: startMinute,
        endMinute: endMinute,
      ),
    );
  }

  segments.sort((first, second) {
    final startComparison = first.startMinute.compareTo(second.startMinute);
    if (startComparison != 0) return startComparison;
    return second.endMinute.compareTo(first.endMinute);
  });

  final placements = <_WeekEventPlacement>[];
  var groupStart = 0;
  while (groupStart < segments.length) {
    var groupEnd = groupStart + 1;
    var latestEnd = segments[groupStart].endMinute;
    while (groupEnd < segments.length &&
        segments[groupEnd].startMinute < latestEnd) {
      latestEnd = math.max(latestEnd, segments[groupEnd].endMinute);
      groupEnd++;
    }

    final laneEnds = <double>[];
    final lanes = <int>[];
    for (var index = groupStart; index < groupEnd; index++) {
      final segment = segments[index];
      var lane = laneEnds.indexWhere((end) => end <= segment.startMinute);
      if (lane == -1) {
        lane = laneEnds.length;
        laneEnds.add(segment.endMinute);
      } else {
        laneEnds[lane] = segment.endMinute;
      }
      lanes.add(lane);
    }

    for (var index = groupStart; index < groupEnd; index++) {
      final segment = segments[index];
      final top = segment.startMinute / 60 * hourHeight;
      final rawHeight =
          (segment.endMinute - segment.startMinute) / 60 * hourHeight;
      final minimumHeight = math.max(4.0, math.min(20.0, hourHeight / 2));
      placements.add(
        _WeekEventPlacement(
          event: segment.event,
          top: top,
          height: math.min(
            math.max(rawHeight, minimumHeight),
            gridHeight - top,
          ),
          lane: lanes[index - groupStart],
          laneCount: laneEnds.length,
        ),
      );
    }

    groupStart = groupEnd;
  }

  return placements;
}

double _minuteOfDay(DateTime date) =>
    date.hour * 60 + date.minute + date.second / 60;
