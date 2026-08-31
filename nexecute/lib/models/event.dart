import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/models/event_recurrence.dart';

class Event {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final List<String> tags;
  final EventReminder reminder;
  final EventRecurrence recurrence;
  final DateTime? recurrenceSeriesStartTime;
  final DateTime? recurrenceSeriesEndTime;

  const Event({
    required this.id,
    required this.title,
    this.description = '',
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
    this.tags = const [],
    this.reminder = EventReminder.none,
    this.recurrence = EventRecurrence.none,
    this.recurrenceSeriesStartTime,
    this.recurrenceSeriesEndTime,
  });

  bool get isGeneratedOccurrence => recurrenceSeriesStartTime != null;

  DateTime get seriesStartTime => recurrenceSeriesStartTime ?? startTime;

  DateTime get seriesEndTime => recurrenceSeriesEndTime ?? endTime;

  Event copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    List<String>? tags,
    EventReminder? reminder,
    EventRecurrence? recurrence,
    DateTime? recurrenceSeriesStartTime,
    DateTime? recurrenceSeriesEndTime,
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
      recurrence: recurrence ?? this.recurrence,
      recurrenceSeriesStartTime:
          recurrenceSeriesStartTime ?? this.recurrenceSeriesStartTime,
      recurrenceSeriesEndTime:
          recurrenceSeriesEndTime ?? this.recurrenceSeriesEndTime,
    );
  }

  @override
  String toString() {
    return 'Event(id: $id, title: $title, description: $description, startTime: $startTime, endTime: $endTime, isAllDay: $isAllDay, tags: $tags, reminder: $reminder, recurrence: $recurrence)';
  }
}
