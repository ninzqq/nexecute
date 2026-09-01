import 'package:flutter/material.dart';
import 'package:nexecute/home/bottomsheets/event_reminder_field.dart';
import 'package:nexecute/home/bottomsheets/event_recurrence_field.dart';
import 'package:nexecute/home/bottomsheets/utils.dart';
import 'package:nexecute/home/widgets/item_time_picker.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/models/event_recurrence.dart';

class EventScheduleFields extends StatelessWidget {
  const EventScheduleFields({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
    required this.reminder,
    required this.recurrence,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onAllDayChanged,
    required this.onReminderChanged,
    required this.onRecurrenceChanged,
    this.selectedStartDate,
  });

  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final EventReminder reminder;
  final EventRecurrence recurrence;
  final DateTime? selectedStartDate;
  final ValueChanged<DateTime> onStartTimeChanged;
  final ValueChanged<DateTime> onEndTimeChanged;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final ValueChanged<bool> onAllDayChanged;
  final ValueChanged<EventReminder> onReminderChanged;
  final ValueChanged<EventRecurrence> onRecurrenceChanged;

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
            Expanded(
              child: TextButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  formatDate(selectedStartDate ?? startTime),
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => _pickStartDate(context),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.arrow_right_alt),
            ),
            Expanded(
              child: TextButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  formatDate(endTime),
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => _pickEndDate(context),
              ),
            ),
          ],
        ),
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            title: const Text('All day'),
            value: isAllDay,
            checkColor: Theme.of(context).colorScheme.onPrimary,
            onChanged: (value) => onAllDayChanged(value ?? false),
          ),
        ),
        EventReminderField(reminder: reminder, onChanged: onReminderChanged),
        const SizedBox(height: 8),
        EventRecurrenceField(
          recurrence: recurrence,
          onChanged: onRecurrenceChanged,
        ),
      ],
    );
  }
}
