import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexecute/domain/calendar/calendar_day.dart';
import 'package:nexecute/domain/calendar/calendar_month.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/themes.dart';
import 'package:nexecute/ui/calendar/event_date_utils.dart';

class MonthView extends StatelessWidget {
  const MonthView({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.events,
    required this.onDaySelected,
  });

  final CalendarMonth month;
  final DateTime selectedDay;
  final List<Event> events;
  final ValueChanged<DateTime> onDaySelected;

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
              final cellHeight = constraints.maxHeight / rowCount;

              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
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
  });

  final CalendarDay day;
  final List<Event> events;
  final bool isInMonth;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _EventMarker(event: events.first),
                      if (events.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, left: 2),
                          child: Text(
                            '+${events.length - 1}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: palette.secondary,
                            ),
                          ),
                        ),
                    ],
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
  const _EventMarker({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        event.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: palette.onSurface, fontSize: 9),
      ),
    );
  }
}
