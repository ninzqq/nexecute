import 'package:flutter/material.dart';
import '../../domain/calendar/calendar_week.dart';
import '../../models/event.dart';
import 'day_column.dart';
import 'event_date_utils.dart';

class WeekView extends StatelessWidget {
  final CalendarWeek week;
  final List<Event> events;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  const WeekView({
    super.key,
    required this.week,
    required this.events,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children:
                    week.days
                        .map(
                          (day) => Expanded(
                            child: DayColumn(
                              day: day,
                              events: eventsForDay(events, day.date),
                              isSelected: isSameCalendarDay(
                                day.date,
                                selectedDay,
                              ),
                              onSelected: () => onDaySelected(day.date),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
