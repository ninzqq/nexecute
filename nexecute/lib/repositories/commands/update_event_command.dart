import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/models/event_recurrence.dart';

class UpdateEventCommand {
  UpdateEventCommand({
    required this.eventId,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
    required List<String> tags,
    required this.reminder,
    this.recurrence = EventRecurrence.none,
  }) : tags = List.unmodifiable(tags);

  factory UpdateEventCommand.fromEvent(Event event) {
    return UpdateEventCommand(
      eventId: event.id,
      title: event.title,
      description: event.description,
      startTime: event.seriesStartTime,
      endTime: event.seriesEndTime,
      isAllDay: event.isAllDay,
      tags: event.tags,
      reminder: event.reminder,
      recurrence: event.recurrence,
    );
  }

  final String eventId;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final List<String> tags;
  final EventReminder reminder;
  final EventRecurrence recurrence;

  Event toEvent() {
    return Event(
      id: eventId,
      title: title,
      description: description,
      startTime: startTime,
      endTime: endTime,
      isAllDay: isAllDay,
      tags: tags,
      reminder: reminder,
      recurrence: recurrence,
    );
  }
}
