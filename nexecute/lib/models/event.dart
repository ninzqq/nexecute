import 'package:nexecute/models/event_reminder.dart';

class Event {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final List<String> tags;
  final EventReminder reminder;

  const Event({
    required this.id,
    required this.title,
    this.description = '',
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
    this.tags = const [],
    this.reminder = EventReminder.none,
  });

  Event copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    List<String>? tags,
    EventReminder? reminder,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      tags: tags ?? this.tags,
      reminder: reminder ?? this.reminder,
    );
  }

  @override
  String toString() {
    return 'Event(id: $id, title: $title, description: $description, startTime: $startTime, endTime: $endTime, isAllDay: $isAllDay, tags: $tags, reminder: $reminder)';
  }
}
