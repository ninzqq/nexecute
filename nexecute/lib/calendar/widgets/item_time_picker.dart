import 'package:flutter/material.dart';

class ItemTimePicker extends StatelessWidget {
  final DateTime time;
  final IconData icon;
  final Function(DateTime) onTimeChanged;

  const ItemTimePicker({
    super.key,
    required this.time,
    required this.icon,
    required this.onTimeChanged,
  });

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        TextButton(
          onPressed: () async {
            final selectedTime = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(time),
            );
            if (selectedTime != null) {
              final newDateTime = DateTime(
                time.year,
                time.month,
                time.day,
                selectedTime.hour,
                selectedTime.minute,
              );
              onTimeChanged(newDateTime);
            }
          },
          child: Text(_formatTime(time)),
        ),
      ],
    );
  }
}
