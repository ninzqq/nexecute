import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexecute/domain/calendar/calendar_day.dart';
import 'package:nexecute/domain/calendar/calendar_month.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/themes.dart';
import 'package:nexecute/ui/calendar/event_date_utils.dart';

const _eventMarkerHeight = 17.0;
const _eventMarkerSpacing = 2.0;
const _overflowLabelHeight = 14.0;
const _minimumMonthCellHeight = 32.0;

int visibleMonthEventCount({
  required int eventCount,
  required double availableHeight,
}) {
  if (eventCount <= 0 || availableHeight <= 0) return 0;

  int markerCapacity(double height) => math.max(
    0,
    ((height + _eventMarkerSpacing) /
            (_eventMarkerHeight + _eventMarkerSpacing))
        .floor(),
  );

  final capacity = markerCapacity(availableHeight);
  if (eventCount <= capacity) return eventCount;

  final heightWithOverflowReserved =
      availableHeight - _overflowLabelHeight - _eventMarkerSpacing;
  return math.min(eventCount, markerCapacity(heightWithOverflowReserved));
}

class MonthView extends StatelessWidget {
  const MonthView({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.events,
    required this.onDaySelected,
    required this.onEventSelected,
  });

  final CalendarMonth month;
  final DateTime selectedDay;
  final List<Event> events;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<Event> onEventSelected;

  @override
  Widget build(BuildContext context) {
    final days = month.days;

    return Column(
      children: [
        const _WeekdayHeader(),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final rowCount = month.weeks.length;
              final cellWidth = constraints.maxWidth / 7;
              final fittedCellHeight = constraints.maxHeight / rowCount;
              final cellHeight = math.max(
                fittedCellHeight,
                _minimumMonthCellHeight,
              );
              final needsScrolling = cellHeight > fittedCellHeight;

              return GridView.builder(
                physics:
                    needsScrolling
                        ? const ClampingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: cellWidth / cellHeight,
                ),
                itemCount: days.length,
                itemBuilder: (context, index) {
                  final day = days[index];
                  return _MonthDayCell(
                    day: day,
                    events: eventsForDay(events, day.date),
                    isInMonth: month.contains(day.date),
                    isSelected: isSameCalendarDay(day.date, selectedDay),
                    isToday: isSameCalendarDay(day.date, DateTime.now()),
                    onTap: () => onDaySelected(day.date),
                    onEventSelected: (event) {
                      onDaySelected(day.date);
                      onEventSelected(event);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final monday = DateTime(2024, 1, 1);
    return SizedBox(
      height: 32,
      child: Row(
        children: List.generate(7, (index) {
          final date = monday.add(Duration(days: index));
          final weekend = date.weekday >= DateTime.saturday;
          return Expanded(
            child: Center(
              child: Text(
                DateFormat.E().format(date),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: weekend ? palette.secondary : palette.onSurface,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.day,
    required this.events,
    required this.isInMonth,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
    required this.onEventSelected,
  });

  final CalendarDay day;
  final List<Event> events;
  final bool isInMonth;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;
  final ValueChanged<Event> onEventSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appPalette;
    final borderColor = palette.outline.withValues(alpha: 0.6);
    final background = switch ((isSelected, day.isWeekend)) {
      (true, _) => palette.primary.withValues(alpha: 0.2),
      (false, true) => palette.surfaceRaised,
      _ => Colors.transparent,
    };

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(4, 3, 4, 2),
        decoration: BoxDecoration(
          color: background,
          border: Border(
            right: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
          ),
        ),
        child: Opacity(
          opacity: isInMonth ? 1 : 0.35,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration:
                    isToday
                        ? BoxDecoration(
                          color: palette.secondary.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        )
                        : null,
                child: Text(
                  '${day.dayNumber}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color:
                        isSelected || isToday
                            ? palette.secondary
                            : palette.onSurface,
                    fontWeight:
                        isSelected || isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              if (events.isNotEmpty)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final visibleCount = visibleMonthEventCount(
                        eventCount: events.length,
                        availableHeight: constraints.maxHeight,
                      );
                      final hiddenCount = events.length - visibleCount;
                      final showOverflow =
                          hiddenCount > 0 &&
                          constraints.maxHeight >= _overflowLabelHeight;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (
                            var index = 0;
                            index < visibleCount;
                            index++
                          ) ...[
                            if (index > 0)
                              const SizedBox(height: _eventMarkerSpacing),
                            _EventMarker(
                              event: events[index],
                              onTap: () => onEventSelected(events[index]),
                            ),
                          ],
                          if (showOverflow) ...[
                            if (visibleCount > 0)
                              const SizedBox(height: _eventMarkerSpacing),
                            SizedBox(
                              height: _overflowLabelHeight,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Text(
                                  '+$hiddenCount',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: palette.secondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventMarker extends StatelessWidget {
  const _EventMarker({required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return SizedBox(
      height: _eventMarkerHeight,
      child: Material(
        color: palette.primary.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(3),
        child: InkWell(
          borderRadius: BorderRadius.circular(3),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: palette.onSurface,
                fontSize: 9,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
