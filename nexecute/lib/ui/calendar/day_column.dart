import 'package:flutter/material.dart';
import '../../domain/calendar/calendar_day.dart';
import 'package:intl/intl.dart';

class DayColumn extends StatelessWidget {
  final CalendarDay day;

  const DayColumn({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final isWeekend = day.isWeekend;
    final dateLabel = DateFormat('EEE d').format(day.date);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
        color:
            isWeekend
                ? Theme.of(context).colorScheme.surfaceContainerHigh
                : null,
      ),
      child: Column(
        children: [
          // Sticky-ish header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            color: Theme.of(context).colorScheme.surface,
            child: Text(
              dateLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),

          // Events area (placeholder for now)
          Container(
            height: 600, // intentionally tall
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.all(8),
            child: Text('Events', style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
