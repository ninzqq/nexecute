import 'package:flutter/material.dart';
import 'package:nexecute/home/bottomsheets/item_editor.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/services/firestore.dart';
import 'package:nexecute/shared/styles.dart';

class EventDetailsBottomSheet extends StatelessWidget {
  final Event event;

  const EventDetailsBottomSheet({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: drawerBgColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  showItemEditor(context, event: event, isEditing: true);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  FirestoreService().deleteCurrentlyOpenEvent(event);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: snackBarBgColor,
                      content: Text('Event deleted.'),
                    ),
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          if (event.description.isNotEmpty) ...[
            Text(
              event.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16.0),
          ],
          Row(
            children: [
              const Icon(Icons.access_time),
              const SizedBox(width: 8.0),
              Text(
                event.isAllDay
                    ? 'All day'
                    : '${_formatTime(event.startTime)} - ${_formatTime(event.endTime)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Row(
            children: [
              const Icon(Icons.calendar_today),
              const SizedBox(width: 8.0),
              Text(
                _formatDate(event.startTime),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 200.0),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }
}
