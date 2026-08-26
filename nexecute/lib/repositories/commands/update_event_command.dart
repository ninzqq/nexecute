import 'package:nexecute/models/event.dart';

class UpdateEventCommand {
  UpdateEventCommand({
    required this.eventId,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
    required List<String> tags,
  }) : tags = List.unmodifiable(tags);

  factory UpdateEventCommand.fromEvent(Event event) {
    return UpdateEventCommand(
      eventId: event.id,
      title: event.title,
      description: event.description,
      startTime: event.startTime,
      endTime: event.endTime,
      isAllDay: event.isAllDay,
      tags: event.tags,
    );
  }

  final String eventId;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final List<String> tags;
}
