import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexecute/domain/calendar/calendar_day.dart';
import 'package:nexecute/domain/calendar/calendar_week.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/themes.dart';
import 'package:nexecute/ui/calendar/day_column.dart';
import 'package:nexecute/ui/calendar/event_date_utils.dart';

const _timeGutterWidth = 38.0;
const weekInitialHour = 7;
const weekInitialScrollOffset = weekHourHeight * weekInitialHour;

class WeekView extends StatelessWidget {
  const WeekView({
    super.key,
    required this.week,
    required this.events,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onEventSelected,
    required this.timeScrollController,
  });

  final CalendarWeek week;
  final List<Event> events;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<Event> onEventSelected;
  final ScrollController timeScrollController;

  @override
  Widget build(BuildContext context) {
    final allDayEvents = [
      for (final day in week.days)
        eventsForDay(
          events,
          day.date,
        ).where((event) => event.isAllDay).toList(),
    ];
    final hasAllDayEvents = allDayEvents.any((events) => events.isNotEmpty);

    return Column(
      children: [
        _WeekDateHeaders(
          days: week.days,
          selectedDay: selectedDay,
          onDaySelected: onDaySelected,
        ),
        if (hasAllDayEvents)
          _AllDayEventsRow(
            days: week.days,
            eventsByDay: allDayEvents,
            onDaySelected: onDaySelected,
            onEventSelected: onEventSelected,
          ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('week-time-grid-scroll-view'),
            controller: timeScrollController,
            child: SizedBox(
              height: weekTimeGridHeight,
              child: Row(
                key: const Key('week-time-grid'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _timeGutterWidth,
                    child: const _HourGutter(hourHeight: weekHourHeight),
                  ),
                  for (final day in week.days)
                    Expanded(
                      child: DayColumn(
                        day: day,
                        events: eventsForDay(events, day.date),
                        isSelected: isSameCalendarDay(day.date, selectedDay),
                        hourHeight: weekHourHeight,
                        onSelected: () => onDaySelected(day.date),
                        onEventSelected: (event) {
                          onDaySelected(day.date);
                          onEventSelected(event);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekDateHeaders extends StatelessWidget {
  const _WeekDateHeaders({
    required this.days,
    required this.selectedDay,
    required this.onDaySelected,
  });

  final List<CalendarDay> days;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: _timeGutterWidth),
          for (final day in days)
            Expanded(
              child: Material(
                color:
                    isSameCalendarDay(day.date, selectedDay)
                        ? palette.primary.withValues(alpha: 0.18)
                        : Theme.of(context).colorScheme.surface,
                child: InkWell(
                  onTap: () => onDaySelected(day.date),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: palette.outline)),
                    ),
                    child: Text(
                      DateFormat('EEE\nd').format(day.date),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color:
                            day.isWeekend
                                ? palette.secondary
                                : palette.onSurface,
                        fontWeight:
                            isSameCalendarDay(day.date, selectedDay)
                                ? FontWeight.bold
                                : FontWeight.normal,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HourGutter extends StatelessWidget {
  const _HourGutter({required this.hourHeight});

  final double hourHeight;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return SizedBox(
      height: hourHeight * 24,
      child: Stack(
        children: [
          for (var hour = 0; hour < 24; hour++)
            Positioned(
              key: ValueKey('week-hour-$hour'),
              top: hour * hourHeight,
              height: hourHeight,
              left: 0,
              right: 4,
              child: Align(
                alignment: Alignment.topRight,
                child: Text(
                  hour.toString().padLeft(2, '0'),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.onSurface.withValues(alpha: 0.62),
                    fontSize: (hourHeight * 0.48).clamp(6.0, 9.0),
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AllDayEventsRow extends StatelessWidget {
  const _AllDayEventsRow({
    required this.days,
    required this.eventsByDay,
    required this.onDaySelected,
    required this.onEventSelected,
  });

  final List<CalendarDay> days;
  final List<List<Event>> eventsByDay;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<Event> onEventSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 104),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _timeGutterWidth,
            child: Center(
              child: Text(
                'All day',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.onSurface.withValues(alpha: 0.7),
                  fontSize: 9,
                ),
              ),
            ),
          ),
          for (var index = 0; index < days.length; index++)
            Expanded(
              child: InkWell(
                onTap: () => onDaySelected(days[index].date),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: palette.outline)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final event in eventsByDay[index])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Material(
                              color: palette.primary.withValues(alpha: 0.28),
                              borderRadius: BorderRadius.circular(3),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () {
                                  onDaySelected(days[index].date);
                                  onEventSelected(event);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: Text(
                                    event.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall?.copyWith(
                                      color: palette.onSurface,
                                      fontSize: 9,
                                      height: 1.05,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
