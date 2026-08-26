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
const _weekNumberColumnWidth = 30.0;

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
    this.showWeekNumbers = true,
    required this.selectedDay,
    required this.events,
    required this.onDaySelected,
    required this.onEventSelected,
  });

  final CalendarMonth month;
  final bool showWeekNumbers;
  final DateTime selectedDay;
  final List<Event> events;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<Event> onEventSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WeekdayHeader(showWeekNumbers: showWeekNumbers),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final rowCount = month.weeks.length;
              final fittedCellHeight = constraints.maxHeight / rowCount;
              final cellHeight = math.max(
                fittedCellHeight,
                _minimumMonthCellHeight,
              );
              final needsScrolling = cellHeight > fittedCellHeight;

              return ListView.builder(
                physics:
                    needsScrolling
                        ? const ClampingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                itemCount: rowCount,
                itemBuilder: (context, weekIndex) {
                  final week = month.weeks[weekIndex];
                  return SizedBox(
                    height: cellHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showWeekNumbers)
                          SizedBox(
                            width: _weekNumberColumnWidth,
                            child: _WeekNumberCell(
                              isoYear: week.year,
                              weekNumber: week.weekNumber,
                            ),
                          ),
                        for (final day in week.days)
                          Expanded(
                            child: _MonthDayCell(
                              day: day,
                              events: eventsForDay(events, day.date),
                              isInMonth: month.contains(day.date),
                              isSelected: isSameCalendarDay(
                                day.date,
                                selectedDay,
                              ),
                              isToday: isSameCalendarDay(
                                day.date,
                                DateTime.now(),
                              ),
                              onTap: () => onDaySelected(day.date),
                              onEventSelected: (event) {
                                onDaySelected(day.date);
                                onEventSelected(event);
                              },
                            ),
                          ),
                      ],
                    ),
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
  const _WeekdayHeader({required this.showWeekNumbers});

  final bool showWeekNumbers;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final monday = DateTime(2024, 1, 1);
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          if (showWeekNumbers)
            SizedBox(
              key: const Key('month-week-number-header'),
              width: _weekNumberColumnWidth,
              child: Center(
                child: Text(
                  'Wk',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),
          for (var index = 0; index < 7; index++)
            Expanded(
              child: Center(
                child: Text(
                  DateFormat.E().format(monday.add(Duration(days: index))),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: index >= 5 ? palette.secondary : palette.onSurface,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekNumberCell extends StatelessWidget {
  const _WeekNumberCell({required this.isoYear, required this.weekNumber});

  final int isoYear;
  final int weekNumber;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Semantics(
      label: 'Week $weekNumber of $isoYear',
      excludeSemantics: true,
      child: Container(
        key: ValueKey('month-week-number-$isoYear-$weekNumber'),
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 9),
        decoration: BoxDecoration(
          color: palette.surfaceRaised.withValues(alpha: 0.5),
          border: Border(
            right: BorderSide(color: palette.outline.withValues(alpha: 0.6)),
            bottom: BorderSide(color: palette.outline.withValues(alpha: 0.6)),
          ),
        ),
        child: Text(
          '$weekNumber',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: palette.onSurface.withValues(alpha: 0.72),
            fontWeight: FontWeight.w600,
          ),
        ),
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
