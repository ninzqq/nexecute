import 'package:flutter/material.dart';
import 'package:nexecute/models/event_recurrence.dart';
import 'package:nexecute/shared/event_recurrence_labels.dart';

class EventRecurrenceField extends StatelessWidget {
  const EventRecurrenceField({
    super.key,
    required this.recurrence,
    required this.onChanged,
  });

  final EventRecurrence recurrence;
  final ValueChanged<EventRecurrence> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<EventRecurrence>(
      key: ValueKey(recurrence),
      initialValue: recurrence,
      decoration: const InputDecoration(
        labelText: 'Repeat',
        prefixIcon: Icon(Icons.repeat_rounded),
        border: OutlineInputBorder(),
      ),
      items: [
        for (final option in EventRecurrence.values)
          DropdownMenuItem(value: option, child: Text(option.editorLabel)),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}
