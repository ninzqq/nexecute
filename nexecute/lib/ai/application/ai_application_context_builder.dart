import 'dart:convert';

import 'package:nexecute/ai/domain/ai_application_context.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/todo_item.dart';

abstract final class AiApplicationContextBuilder {
  /// Combines already-bounded read results into the single envelope shown in
  /// the composer and sent with one request.
  static AiApplicationContextEnvelope compose({
    required DateTime generatedAt,
    required List<AiApplicationContextEnvelope> sources,
  }) {
    final notes = <AiNoteContextItem>[];
    final tasks = <AiTaskContextItem>[];
    final events = <AiEventContextItem>[];
    AiEventContextRange? eventRange;
    var omittedNotes = 0;
    var omittedTasks = 0;
    var omittedEvents = 0;
    for (final source in sources) {
      for (final attachment in source.attachments) {
        switch (attachment) {
          case AiSelectedNotesContextAttachment():
            notes.addAll(attachment.notes);
            omittedNotes += attachment.omittedCount;
          case AiActiveTasksContextAttachment():
            if (tasks.isNotEmpty) {
              throw ArgumentError(
                'Only one active-task attachment is allowed.',
              );
            }
            tasks.addAll(attachment.tasks);
            omittedTasks += attachment.omittedCount;
          case AiEventsContextAttachment():
            if (eventRange != null) {
              throw ArgumentError('Only one event attachment is allowed.');
            }
            eventRange = attachment.range;
            events.addAll(attachment.events);
            omittedEvents += attachment.omittedCount;
        }
      }
    }
    if (notes.length > AiApplicationContextLimits.maxSelectedNotes) {
      omittedNotes +=
          notes.length - AiApplicationContextLimits.maxSelectedNotes;
      notes.removeRange(
        AiApplicationContextLimits.maxSelectedNotes,
        notes.length,
      );
    }
    if (tasks.length > AiApplicationContextLimits.maxActiveTasks) {
      omittedTasks += tasks.length - AiApplicationContextLimits.maxActiveTasks;
      tasks.removeRange(
        AiApplicationContextLimits.maxActiveTasks,
        tasks.length,
      );
    }
    if (events.length > AiApplicationContextLimits.maxEvents) {
      omittedEvents += events.length - AiApplicationContextLimits.maxEvents;
      events.removeRange(AiApplicationContextLimits.maxEvents, events.length);
    }

    var payloadTruncated = sources.any((source) => source.payloadTruncated);
    AiApplicationContextEnvelope envelope() => AiApplicationContextEnvelope(
      generatedAt: generatedAt,
      payloadTruncated: payloadTruncated,
      attachments: [
        if (notes.isNotEmpty || omittedNotes > 0)
          AiSelectedNotesContextAttachment(
            notes: notes,
            omittedCount: omittedNotes,
          ),
        if (tasks.isNotEmpty || omittedTasks > 0)
          AiActiveTasksContextAttachment(
            tasks: tasks,
            omittedCount: omittedTasks,
          ),
        if (eventRange != null)
          AiEventsContextAttachment(
            range: eventRange,
            events: events,
            omittedCount: omittedEvents,
          ),
      ],
    );

    var result = envelope();
    while (result.serializedCharacterCount >
        AiApplicationContextLimits.maxPayloadCharacters) {
      payloadTruncated = true;
      if (tasks.isNotEmpty || events.isNotEmpty) {
        if (_serializedItemsLength(tasks) >= _serializedItemsLength(events)) {
          tasks.removeLast();
          omittedTasks++;
        } else {
          events.removeLast();
          omittedEvents++;
        }
      } else if (notes.isNotEmpty) {
        notes.removeLast();
        omittedNotes++;
      } else {
        throw StateError('The empty context envelope exceeds its size limit.');
      }
      result = envelope();
    }
    return result;
  }

  static AiApplicationContextEnvelope build({
    required DateTime generatedAt,
    bool includeActiveTasks = false,
    List<TodoItem> tasks = const [],
    CalendarQueryRange? eventRange,
    List<Event> events = const [],
    List<Quicxec> selectedNotes = const [],
    bool includeSelectedNotes = false,
    int selectedNoteLimit = AiApplicationContextLimits.maxSelectedNotes,
    int taskLimit = AiApplicationContextLimits.maxActiveTasks,
    int eventLimit = AiApplicationContextLimits.maxEvents,
  }) {
    _validateLimit(
      selectedNoteLimit,
      'selectedNoteLimit',
      AiApplicationContextLimits.maxSelectedNotes,
    );
    _validateLimit(
      taskLimit,
      'taskLimit',
      AiApplicationContextLimits.maxActiveTasks,
    );
    _validateLimit(
      eventLimit,
      'eventLimit',
      AiApplicationContextLimits.maxEvents,
    );
    if (eventRange == null && events.isNotEmpty) {
      throw ArgumentError('eventRange is required when events are provided.');
    }
    if (eventRange != null) _validateEventRange(eventRange);

    var remainingNoteCharacters =
        AiApplicationContextLimits.maxTotalNoteContentCharacters;
    final notes = <AiNoteContextItem>[];
    for (final note in selectedNotes.take(selectedNoteLimit)) {
      final mapped = _mapNote(note, remainingNoteCharacters);
      notes.add(mapped.item);
      remainingNoteCharacters -= mapped.usedContentCharacters;
    }
    var omittedNotes =
        selectedNotes.length > selectedNoteLimit
            ? selectedNotes.length - selectedNoteLimit
            : 0;

    final activeSource =
        includeActiveTasks
            ? tasks.where((task) => !task.isCompleted).toList()
            : const <TodoItem>[];
    final taskItems = [
      for (final task in activeSource.take(taskLimit)) _mapTask(task),
    ];
    var omittedTasks =
        activeSource.length > taskLimit ? activeSource.length - taskLimit : 0;

    final inRangeEvents =
        eventRange == null
            ? <Event>[]
            : events
                .where(
                  (event) => eventRange.overlaps(
                    start: event.startTime,
                    end: event.endTime,
                  ),
                )
                .toList();
    inRangeEvents.sort(
      (first, second) => first.startTime.compareTo(second.startTime),
    );
    final eventItems = [
      for (final event in inRangeEvents.take(eventLimit)) _mapEvent(event),
    ];
    var omittedEvents =
        inRangeEvents.length > eventLimit
            ? inRangeEvents.length - eventLimit
            : 0;
    var payloadTruncated = false;

    AiApplicationContextEnvelope envelope() => AiApplicationContextEnvelope(
      generatedAt: generatedAt,
      payloadTruncated: payloadTruncated,
      attachments: [
        if (includeSelectedNotes || selectedNotes.isNotEmpty)
          AiSelectedNotesContextAttachment(
            notes: notes,
            omittedCount: omittedNotes,
          ),
        if (includeActiveTasks)
          AiActiveTasksContextAttachment(
            tasks: taskItems,
            omittedCount: omittedTasks,
          ),
        if (eventRange != null)
          AiEventsContextAttachment(
            range: AiEventContextRange(
              startInclusive: eventRange.startInclusive,
              endExclusive: eventRange.endExclusive,
            ),
            events: eventItems,
            omittedCount: omittedEvents,
          ),
      ],
    );

    var result = envelope();
    while (result.serializedCharacterCount >
        AiApplicationContextLimits.maxPayloadCharacters) {
      payloadTruncated = true;
      if (taskItems.isNotEmpty || eventItems.isNotEmpty) {
        if (_serializedItemsLength(taskItems) >=
            _serializedItemsLength(eventItems)) {
          taskItems.removeLast();
          omittedTasks += 1;
        } else {
          eventItems.removeLast();
          omittedEvents += 1;
        }
      } else if (notes.isNotEmpty) {
        notes.removeLast();
        omittedNotes += 1;
      } else {
        throw StateError('The empty context envelope exceeds its size limit.');
      }
      result = envelope();
    }
    return result;
  }

  static void _validateEventRange(CalendarQueryRange range) {
    if (!range.endExclusive.isAfter(range.startInclusive)) {
      throw ArgumentError.value(
        range,
        'eventRange',
        'must end after it starts',
      );
    }
    final startDay = DateTime.utc(
      range.startInclusive.year,
      range.startInclusive.month,
      range.startInclusive.day,
    );
    final endDay = DateTime.utc(
      range.endExclusive.year,
      range.endExclusive.month,
      range.endExclusive.day,
    );
    if (endDay.difference(startDay).inDays >
        AiApplicationContextLimits.maxEventRangeDays) {
      throw ArgumentError.value(
        range,
        'eventRange',
        'must not exceed '
            '${AiApplicationContextLimits.maxEventRangeDays} calendar days',
      );
    }
  }

  static void _validateLimit(int value, String name, int maximum) {
    if (value < 0 || value > maximum) {
      throw ArgumentError.value(value, name, 'must be between 0 and $maximum');
    }
  }

  static AiTaskContextItem _mapTask(TodoItem task) {
    final title = _truncate(
      task.title.trim(),
      AiApplicationContextLimits.maxTaskTitleCharacters,
    );
    return AiTaskContextItem(
      title: title.text,
      isCompleted: task.isCompleted,
      titleTruncated: title.truncated,
    );
  }

  static AiEventContextItem _mapEvent(Event event) {
    final title = _truncate(
      event.title.trim(),
      AiApplicationContextLimits.maxTitleCharacters,
    );
    final description = _truncate(
      event.description.trim(),
      AiApplicationContextLimits.maxEventDescriptionCharacters,
    );
    return AiEventContextItem(
      title: title.text,
      titleTruncated: title.truncated,
      startTime: event.startTime,
      endTime: event.endTime,
      isAllDay: event.isAllDay,
      description: description.text,
      descriptionTruncated: description.truncated,
    );
  }

  static _MappedNote _mapNote(Quicxec note, int totalCharactersRemaining) {
    final title = _truncate(
      note.title.trim(),
      AiApplicationContextLimits.maxTitleCharacters,
    );
    final noteBudget = totalCharactersRemaining.clamp(
      0,
      AiApplicationContextLimits.maxNoteContentCharacters,
    );
    if (!note.isChecklist) {
      final content = _truncate(note.text.trim(), noteBudget);
      return _MappedNote(
        item: AiNoteContextItem(
          title: title.text,
          titleTruncated: title.truncated,
          contentType: AiContextNoteContentType.text,
          content: content.text,
          contentTruncated: content.truncated,
          checklistItems: const [],
          omittedChecklistItemCount: 0,
        ),
        usedContentCharacters: content.text.length,
      );
    }

    final sourceItems =
        note.checklistItems
            .where((item) => item.text.trim().isNotEmpty)
            .toList();
    final items = <AiNoteChecklistItemContext>[];
    var charactersRemaining = noteBudget;
    var omittedItems = 0;
    for (var index = 0; index < sourceItems.length; index++) {
      if (items.length >= AiApplicationContextLimits.maxChecklistItemsPerNote ||
          charactersRemaining <= 0) {
        omittedItems += sourceItems.length - index;
        break;
      }
      final item = sourceItems[index];
      final itemLimit = charactersRemaining.clamp(
        0,
        AiApplicationContextLimits.maxChecklistItemCharacters,
      );
      final text = _truncate(item.text.trim(), itemLimit);
      items.add(
        AiNoteChecklistItemContext(
          text: text.text,
          isChecked: item.isChecked,
          textTruncated: text.truncated,
        ),
      );
      charactersRemaining -= text.text.length;
    }
    return _MappedNote(
      item: AiNoteContextItem(
        title: title.text,
        titleTruncated: title.truncated,
        contentType: AiContextNoteContentType.checklist,
        contentTruncated: false,
        checklistItems: items,
        omittedChecklistItemCount: omittedItems,
      ),
      usedContentCharacters: noteBudget - charactersRemaining,
    );
  }

  static int _serializedItemsLength(List<Object> items) =>
      items.fold(0, (length, item) {
        final json = switch (item) {
          final AiTaskContextItem task => jsonEncode(task.toJson()),
          final AiEventContextItem event => jsonEncode(event.toJson()),
          _ => jsonEncode(item.toString()),
        };
        return length + json.length;
      });

  static _TruncatedText _truncate(String value, int maxCharacters) {
    if (value.length <= maxCharacters) {
      return _TruncatedText(value, false);
    }
    return _TruncatedText(value.substring(0, maxCharacters), true);
  }
}

class _MappedNote {
  const _MappedNote({required this.item, required this.usedContentCharacters});

  final AiNoteContextItem item;
  final int usedContentCharacters;
}

class _TruncatedText {
  const _TruncatedText(this.text, this.truncated);

  final String text;
  final bool truncated;
}
