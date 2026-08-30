import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_reminder.dart';

const maxCreateEventTitleCharacters = 200;
const maxCreateEventDescriptionCharacters = 4000;
const maxCreateEventTags = 50;
const maxCreateEventTagCharacters = 100;
const maxCreateEventSpanDays = 366;

class CreateEventCommand {
  CreateEventCommand({
    required this.creationId,
    required this.sourceNoteId,
    required String title,
    required String description,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
    required List<String> tags,
    required this.reminder,
    required this.createdAt,
  }) : title = _validateTitle(title),
       description = _validateDescription(description),
       tags = List.unmodifiable(_validateTags(tags)) {
    _validateId(creationId, 'creationId');
    _validateSourceNoteId(sourceNoteId);
    _validateSchedule(
      startTime: startTime,
      endTime: endTime,
      isAllDay: isAllDay,
    );
  }

  static final RegExp _safeId = RegExp(r'^[A-Za-z0-9_-]+$');

  final String creationId;
  final String sourceNoteId;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final List<String> tags;
  final EventReminder reminder;
  final DateTime createdAt;

  String get eventId => 'ai-event-$creationId';

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
    );
  }

  static void _validateId(String value, String name) {
    if (value.isEmpty || value.length > 100 || !_safeId.hasMatch(value)) {
      throw ArgumentError.value(
        value,
        name,
        'Use 1–100 letters, numbers, underscores, or hyphens.',
      );
    }
  }

  static void _validateSourceNoteId(String value) {
    if (value.isEmpty || value.length > 1500 || value.contains('/')) {
      throw ArgumentError.value(
        value,
        'sourceNoteId',
        'A source note ID is required and cannot contain a slash.',
      );
    }
  }

  static String _validateTitle(String value) {
    final title = value.trim();
    if (title.isEmpty ||
        title.length > maxCreateEventTitleCharacters ||
        title.contains('\n') ||
        title.contains('\r')) {
      throw ArgumentError.value(
        value,
        'title',
        'Use one non-empty line of at most '
            '$maxCreateEventTitleCharacters characters.',
      );
    }
    return title;
  }

  static String _validateDescription(String value) {
    final description = value.trim();
    if (description.length > maxCreateEventDescriptionCharacters) {
      throw ArgumentError.value(
        value,
        'description',
        'Use at most $maxCreateEventDescriptionCharacters characters.',
      );
    }
    return description;
  }

  static List<String> _validateTags(List<String> values) {
    if (values.length > maxCreateEventTags) {
      throw ArgumentError.value(
        values,
        'tags',
        'Use at most $maxCreateEventTags tags.',
      );
    }
    final tags = <String>[];
    final normalized = <String>{};
    for (final value in values) {
      final tag = value.trim();
      if (tag.isEmpty ||
          tag.length > maxCreateEventTagCharacters ||
          tag.contains('\n') ||
          tag.contains('\r')) {
        throw ArgumentError.value(
          value,
          'tags',
          'Each tag must be one non-empty line of at most '
              '$maxCreateEventTagCharacters characters.',
        );
      }
      if (!normalized.add(tag.toLowerCase())) {
        throw ArgumentError.value(values, 'tags', 'Tags must be unique.');
      }
      tags.add(tag);
    }
    return tags;
  }

  static void _validateSchedule({
    required DateTime startTime,
    required DateTime endTime,
    required bool isAllDay,
  }) {
    if (startTime.isUtc || endTime.isUtc) {
      throw ArgumentError('Event schedule values must use local device time.');
    }
    if (isAllDay &&
        (startTime.hour != 0 ||
            startTime.minute != 0 ||
            startTime.second != 0 ||
            startTime.millisecond != 0 ||
            startTime.microsecond != 0 ||
            endTime.hour != 0 ||
            endTime.minute != 0 ||
            endTime.second != 0 ||
            endTime.millisecond != 0 ||
            endTime.microsecond != 0)) {
      throw ArgumentError('All-day event endpoints must be local date values.');
    }
    if (isAllDay ? endTime.isBefore(startTime) : !endTime.isAfter(startTime)) {
      throw ArgumentError(
        isAllDay
            ? 'An all-day event cannot end before it starts.'
            : 'A timed event must end after it starts.',
      );
    }
    final startDate = DateTime.utc(
      startTime.year,
      startTime.month,
      startTime.day,
    );
    final endDate = DateTime.utc(endTime.year, endTime.month, endTime.day);
    if (endDate.difference(startDate).inDays >= maxCreateEventSpanDays) {
      throw ArgumentError('The event spans too many days.');
    }
  }
}
