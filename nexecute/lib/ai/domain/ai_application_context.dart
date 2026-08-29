import 'dart:convert';

const aiApplicationContextSchemaVersion = 1;
const aiApplicationContextDataClassification = 'untrustedApplicationData';

abstract final class AiApplicationContextLimits {
  static const maxSelectedNotes = 3;
  static const maxNoteContentCharacters = 4000;
  static const maxTotalNoteContentCharacters = 12000;
  static const maxChecklistItemsPerNote = 50;
  static const maxChecklistItemCharacters = 500;
  static const maxActiveTasks = 50;
  static const maxEvents = 100;
  static const maxEventRangeDays = 31;
  static const maxTitleCharacters = 300;
  static const maxTaskTitleCharacters = 200;
  static const maxEventDescriptionCharacters = 500;
  static const maxPayloadCharacters = 24000;
}

enum AiApplicationContextAttachmentType { selectedNotes, activeTasks, events }

enum AiContextNoteContentType { text, checklist }

class AiApplicationContextEnvelope {
  AiApplicationContextEnvelope({
    required this.generatedAt,
    required List<AiApplicationContextAttachment> attachments,
    this.payloadTruncated = false,
  }) : attachments = List.unmodifiable(attachments);

  final DateTime generatedAt;
  final List<AiApplicationContextAttachment> attachments;
  final bool payloadTruncated;

  Map<String, Object?> toJson() => {
    'schemaVersion': aiApplicationContextSchemaVersion,
    'dataClassification': aiApplicationContextDataClassification,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'payloadTruncated': payloadTruncated,
    'attachments': [for (final attachment in attachments) attachment.toJson()],
  };

  String encode() => jsonEncode(toJson());

  int get serializedCharacterCount => encode().length;
}

sealed class AiApplicationContextAttachment {
  const AiApplicationContextAttachment({required this.omittedCount});

  final int omittedCount;

  AiApplicationContextAttachmentType get type;

  int get itemCount;

  Map<String, Object?> toJson();
}

class AiSelectedNotesContextAttachment extends AiApplicationContextAttachment {
  AiSelectedNotesContextAttachment({
    required List<AiNoteContextItem> notes,
    required super.omittedCount,
  }) : notes = List.unmodifiable(notes);

  final List<AiNoteContextItem> notes;

  @override
  AiApplicationContextAttachmentType get type =>
      AiApplicationContextAttachmentType.selectedNotes;

  @override
  int get itemCount => notes.length;

  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'itemCount': itemCount,
    'omittedCount': omittedCount,
    'items': [for (final note in notes) note.toJson()],
  };
}

class AiActiveTasksContextAttachment extends AiApplicationContextAttachment {
  AiActiveTasksContextAttachment({
    required List<AiTaskContextItem> tasks,
    required super.omittedCount,
  }) : tasks = List.unmodifiable(tasks);

  final List<AiTaskContextItem> tasks;

  @override
  AiApplicationContextAttachmentType get type =>
      AiApplicationContextAttachmentType.activeTasks;

  @override
  int get itemCount => tasks.length;

  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'itemCount': itemCount,
    'omittedCount': omittedCount,
    'items': [for (final task in tasks) task.toJson()],
  };
}

class AiEventsContextAttachment extends AiApplicationContextAttachment {
  AiEventsContextAttachment({
    required this.range,
    required List<AiEventContextItem> events,
    required super.omittedCount,
  }) : events = List.unmodifiable(events);

  final AiEventContextRange range;
  final List<AiEventContextItem> events;

  @override
  AiApplicationContextAttachmentType get type =>
      AiApplicationContextAttachmentType.events;

  @override
  int get itemCount => events.length;

  @override
  Map<String, Object?> toJson() => {
    'type': type.name,
    'range': range.toJson(),
    'itemCount': itemCount,
    'omittedCount': omittedCount,
    'items': [for (final event in events) event.toJson()],
  };
}

class AiTaskContextItem {
  const AiTaskContextItem({
    required this.title,
    required this.isCompleted,
    this.titleTruncated = false,
  });

  final String title;
  final bool isCompleted;
  final bool titleTruncated;

  Map<String, Object?> toJson() => {
    'title': title,
    'isCompleted': isCompleted,
    'titleTruncated': titleTruncated,
  };
}

class AiEventContextRange {
  const AiEventContextRange({
    required this.startInclusive,
    required this.endExclusive,
  });

  final DateTime startInclusive;
  final DateTime endExclusive;

  Map<String, Object?> toJson() => {
    'startInclusive': _toRfc3339(startInclusive),
    'endExclusive': _toRfc3339(endExclusive),
  };
}

class AiEventContextItem {
  const AiEventContextItem({
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
    required this.description,
    this.titleTruncated = false,
    this.descriptionTruncated = false,
  });

  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final String description;
  final bool titleTruncated;
  final bool descriptionTruncated;

  Map<String, Object?> toJson() => {
    'title': title,
    'titleTruncated': titleTruncated,
    'startTime': _toRfc3339(startTime),
    'endTime': _toRfc3339(endTime),
    'isAllDay': isAllDay,
    if (description.isNotEmpty) 'description': description,
    'descriptionTruncated': descriptionTruncated,
  };
}

class AiNoteContextItem {
  AiNoteContextItem({
    required this.title,
    required this.contentType,
    required List<AiNoteChecklistItemContext> checklistItems,
    required this.omittedChecklistItemCount,
    this.content,
    this.titleTruncated = false,
    this.contentTruncated = false,
  }) : checklistItems = List.unmodifiable(checklistItems);

  final String title;
  final AiContextNoteContentType contentType;
  final String? content;
  final List<AiNoteChecklistItemContext> checklistItems;
  final int omittedChecklistItemCount;
  final bool titleTruncated;
  final bool contentTruncated;

  Map<String, Object?> toJson() => {
    'title': title,
    'titleTruncated': titleTruncated,
    'contentType': contentType.name,
    if (content != null) 'content': content,
    'contentTruncated': contentTruncated,
    if (contentType == AiContextNoteContentType.checklist)
      'checklistItems': [for (final item in checklistItems) item.toJson()],
    if (contentType == AiContextNoteContentType.checklist)
      'omittedChecklistItemCount': omittedChecklistItemCount,
  };
}

class AiNoteChecklistItemContext {
  const AiNoteChecklistItemContext({
    required this.text,
    required this.isChecked,
    this.textTruncated = false,
  });

  final String text;
  final bool isChecked;
  final bool textTruncated;

  Map<String, Object?> toJson() => {
    'text': text,
    'isChecked': isChecked,
    'textTruncated': textTruncated,
  };
}

String _toRfc3339(DateTime value) {
  if (value.isUtc) return value.toIso8601String();
  final offset = value.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final absoluteMinutes = offset.inMinutes.abs();
  final hours = (absoluteMinutes ~/ 60).toString().padLeft(2, '0');
  final minutes = (absoluteMinutes % 60).toString().padLeft(2, '0');
  return '${value.toIso8601String()}$sign$hours:$minutes';
}
