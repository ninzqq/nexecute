import 'package:flutter/material.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/shared/event_reminder_labels.dart';

class EventReminderField extends StatelessWidget {
  const EventReminderField({
    super.key,
    required this.reminder,
    required this.onChanged,
  });

  final EventReminder reminder;
  final ValueChanged<EventReminder> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<EventReminder>(
      key: ValueKey(reminder),
      initialValue: reminder,
      decoration: const InputDecoration(
        labelText: 'Reminder',
        prefixIcon: Icon(Icons.notifications_outlined),
        border: OutlineInputBorder(),
      ),
      items: [
        for (final option in EventReminder.values)
          DropdownMenuItem(value: option, child: Text(option.label)),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}
