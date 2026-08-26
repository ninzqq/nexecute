import 'package:flutter/material.dart';
import 'package:nexecute/home/bottomsheets/event_reminder_field.dart';
import 'package:nexecute/home/bottomsheets/utils.dart';
import 'package:nexecute/home/widgets/item_time_picker.dart';
import 'package:nexecute/models/event_reminder.dart';

class EventScheduleFields extends StatelessWidget {
  const EventScheduleFields({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
    required this.reminder,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onAllDayChanged,
    required this.onReminderChanged,
    this.selectedStartDate,
  });

  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final EventReminder reminder;
  final DateTime? selectedStartDate;
  final ValueChanged<DateTime> onStartTimeChanged;
  final ValueChanged<DateTime> onEndTimeChanged;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final ValueChanged<bool> onAllDayChanged;
  final ValueChanged<EventReminder> onReminderChanged;

  Future<void> _pickStartDate(BuildContext context) async {
    final date = await showDatePicker(
      locale: const Locale('fi', 'FI'),
      context: context,
      initialDate: startTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date != null) onStartDateChanged(date);
  }

  Future<void> _pickEndDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: endTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) onEndDateChanged(date);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!isAllDay)
          Row(
            children: [
              const SizedBox(width: 8),
              ItemTimePicker(
                time: startTime,
                icon: Icons.access_time,
                onTimeChanged: onStartTimeChanged,
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_right_alt),
              const SizedBox(width: 16),
              ItemTimePicker(
                time: endTime,
                icon: Icons.access_time,
                onTimeChanged: onEndTimeChanged,
              ),
            ],
          ),
        Row(
          children: [
            const SizedBox(width: 8),
            const Icon(Icons.calendar_today),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _pickStartDate(context),
              child: Text(formatDate(selectedStartDate ?? startTime)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_right_alt),
            const SizedBox(width: 16),
            const Icon(Icons.calendar_today),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _pickEndDate(context),
              child: Text(formatDate(endTime)),
            ),
          ],
        ),
        CheckboxListTile(
          title: const Text('All day'),
          value: isAllDay,
          checkColor: Theme.of(context).colorScheme.onPrimary,
          onChanged: (value) => onAllDayChanged(value ?? false),
        ),
        EventReminderField(reminder: reminder, onChanged: onReminderChanged),
      ],
    );
  }
}
