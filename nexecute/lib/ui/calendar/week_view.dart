import 'package:flutter/material.dart';
import '../../domain/calendar/calendar_week.dart';
import 'week_header.dart';
import 'day_column.dart';

class WeekView extends StatelessWidget {
  final CalendarWeek week;

  const WeekView({super.key, required this.week});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        WeekHeader(week: week),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children:
                    week.days
                        .map((day) => Expanded(child: DayColumn(day: day)))
                        .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
