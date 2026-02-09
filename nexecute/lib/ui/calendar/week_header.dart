import 'package:flutter/material.dart';
import '../../domain/calendar/calendar_week.dart';
import 'package:intl/intl.dart';

class WeekHeader extends StatelessWidget {
  final CalendarWeek week;

  const WeekHeader({super.key, required this.week});

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(week.start);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Text(
            'Week ${week.weekNumber}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          Text(monthLabel, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
