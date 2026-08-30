import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nexecute/ai/application/ai_note_event_prompt.dart';
import 'package:nexecute/ai/domain/ai_chat_message.dart';
import 'package:nexecute/ai/domain/ai_chat_request.dart';
import 'package:nexecute/ai/domain/ai_connection_profile.dart';
import 'package:nexecute/ai/domain/ai_event_proposal.dart';
import 'package:nexecute/ai/domain/ai_stream_event.dart';
import 'package:nexecute/ai/infrastructure/ai_event_proposal_parser.dart';
import 'package:nexecute/ai/repositories/ai_assistant_repository.dart';
import 'package:nexecute/ai/repositories/ai_connection_profile_store.dart';
import 'package:nexecute/ai/repositories/ai_response_handle.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/repositories/commands/create_event_command.dart';
import 'package:uuid/uuid.dart';

enum AiNoteEventExtractionStatus {
  loading,
  ready,
  generating,
  completed,
  cancelled,
  failed,
}

enum AiEventReviewField { startDate, startTime, endDate, endTime, isAllDay }

@immutable
class AiEventProposalReviewDraft {
  const AiEventProposalReviewDraft({
    required this.title,
    required this.description,
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
    required this.isAllDay,
    this.tags = const [],
    this.reminder = EventReminder.none,
  });

  final String title;
  final String description;
  final DateTime? startDate;
  final Duration? startTime;
  final DateTime? endDate;
  final Duration? endTime;
  final bool? isAllDay;
  final List<String> tags;
  final EventReminder reminder;

  String? get validationMessage {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return 'Enter an event title.';
    if (trimmedTitle.contains('\n') || trimmedTitle.contains('\r')) {
      return 'Use a single-line event title.';
    }
    if (trimmedTitle.length > aiMaxProposedEventTitleCharacters) {
      return 'Use at most $aiMaxProposedEventTitleCharacters title characters.';
    }
    if (description.trim().length > aiMaxProposedEventDescriptionCharacters) {
      return 'Use at most $aiMaxProposedEventDescriptionCharacters description characters.';
    }
    if (tags.length > maxCreateEventTags ||
        tags.any(
          (tag) =>
              tag.trim().isEmpty ||
              tag.trim().length > maxCreateEventTagCharacters ||
              tag.contains('\n') ||
              tag.contains('\r'),
        )) {
      return 'Review the selected tags.';
    }
    if (tags.map((tag) => tag.trim().toLowerCase()).toSet().length !=
        tags.length) {
      return 'Review the selected tags.';
    }
    if (isAllDay == null) return 'Choose timed or all-day.';
    if (startDate == null) return 'Choose a start date.';
    if (endDate == null) return 'Choose an end date.';
    if (!isAllDay! && startTime == null) return 'Choose a start time.';
    if (!isAllDay! && endTime == null) return 'Choose an end time.';
    if (!isAllDay! &&
        (!_isWallClockTime(startTime!) || !_isWallClockTime(endTime!))) {
      return 'Choose valid wall-clock times.';
    }

    final start = _combine(startDate!, isAllDay! ? Duration.zero : startTime!);
    final end = _combine(endDate!, isAllDay! ? Duration.zero : endTime!);
    if (isAllDay!) {
      if (end.isBefore(start)) return 'The event cannot end before it starts.';
    } else if (!end.isAfter(start)) {
      return 'A timed event must end after it starts.';
    }
    if (_utcDateOnly(endDate!).difference(_utcDateOnly(startDate!)).inDays >=
        aiMaxProposedEventSpanDays) {
      return 'The event spans too many days.';
    }
    return null;
  }

  bool get isComplete => validationMessage == null;

  static DateTime _combine(DateTime date, Duration time) => DateTime(
    date.year,
    date.month,
    date.day,
    time.inHours,
    time.inMinutes.remainder(60),
  );

  static DateTime _utcDateOnly(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  static bool _isWallClockTime(Duration value) =>
      !value.isNegative && value < const Duration(days: 1);
}

class AiNoteEventExtractionController extends ChangeNotifier {
  AiNoteEventExtractionController({
    required AiAssistantRepository assistantRepository,
    required AiConnectionProfileStore connectionProfileStore,
    String Function()? idFactory,
    DateTime Function()? clock,
  }) : _assistantRepository = assistantRepository,
       _connectionProfileStore = connectionProfileStore,
       _idFactory = idFactory ?? const Uuid().v4,
       _clock = clock ?? DateTime.now;

  final AiAssistantRepository _assistantRepository;
  final AiConnectionProfileStore _connectionProfileStore;
  final String Function() _idFactory;
  final DateTime Function() _clock;

  AiResponseHandle? _handle;
  StreamSubscription<AiStreamEvent>? _subscription;
  DateTime? _referenceLocalDateTime;
  bool _finalized = true;
  bool _disposed = false;

  AiNoteEventExtractionStatus status = AiNoteEventExtractionStatus.loading;
  AiConnectionProfile? activeProfile;
  AiEventProposal? proposal;
  AiEventProposalReviewDraft? reviewDraft;
  Set<AiEventReviewField> originallyMissingFields = const {};
  String reasoning = '';
  String? errorMessage;

  bool get canContinue => reviewDraft?.isComplete ?? false;

  Future<void> initialize() async {
    try {
      activeProfile = await _connectionProfileStore.getActiveProfile();
      status = AiNoteEventExtractionStatus.ready;
      if (activeProfile == null) {
        errorMessage = 'Select an AI connection in Settings first.';
      }
    } catch (_) {
      status = AiNoteEventExtractionStatus.failed;
      errorMessage = 'Could not load the active AI connection.';
    }
    _notify();
  }

  AiNoteEventPrompt buildPrompt({
    required String noteTitle,
    required String noteContent,
  }) {
    final now = _referenceLocalDateTime ??= _clock();
    return AiNoteEventPromptBuilder.build(
      noteTitle: noteTitle,
      noteContent: noteContent,
      referenceLocalDateTime: now,
      utcOffset: now.timeZoneOffset,
    );
  }

  Future<void> start({
    required String noteId,
    required String noteTitle,
    required String noteContent,
  }) async {
    if (status == AiNoteEventExtractionStatus.generating) return;
    final profile = activeProfile;
    if (profile == null) return;

    final AiNoteEventPrompt prompt;
    try {
      prompt = buildPrompt(noteTitle: noteTitle, noteContent: noteContent);
    } on ArgumentError catch (error) {
      status = AiNoteEventExtractionStatus.failed;
      errorMessage = error.message?.toString() ?? 'The note is too large.';
      _notify();
      return;
    }

    status = AiNoteEventExtractionStatus.generating;
    proposal = null;
    reviewDraft = null;
    originallyMissingFields = const {};
    reasoning = '';
    errorMessage = null;
    _finalized = false;
    _notify();

    try {
      final handle = await _assistantRepository.startResponse(
        AiChatRequest(
          connectionProfile: profile,
          conversationId: 'note-event-extraction:$noteId',
          systemInstruction: prompt.systemInstruction,
          messages: [
            AiChatMessage(
              id: _idFactory(),
              role: AiMessageRole.user,
              content: prompt.userMessage,
              createdAt: _clock(),
            ),
          ],
        ),
      );
      if (_finalized || _disposed) {
        await handle.cancel();
        return;
      }
      _handle = handle;
      final output = StringBuffer();
      _subscription = handle.events.listen(
        (event) {
          if (_finalized) return;
          switch (event) {
            case AiTextDelta(:final text):
              output.write(text);
            case AiReasoningDelta(:final text):
              reasoning = '$reasoning$text';
              _notify();
            case AiResponseCompleted():
              _complete(output.toString());
            case AiResponseFailed(:final message, :final code):
              _finish(
                code == 'cancelled'
                    ? AiNoteEventExtractionStatus.cancelled
                    : AiNoteEventExtractionStatus.failed,
                message,
              );
            case AiToolCallRequested():
              _finish(
                AiNoteEventExtractionStatus.failed,
                'The model returned a tool call instead of an event proposal.',
              );
          }
        },
        onError:
            (_) => _finish(
              AiNoteEventExtractionStatus.failed,
              'The AI response was interrupted.',
            ),
        onDone: () {
          if (!_finalized) {
            _finish(
              AiNoteEventExtractionStatus.failed,
              'The AI response ended before completing the proposal.',
            );
          }
        },
      );
    } catch (_) {
      _finish(
        AiNoteEventExtractionStatus.failed,
        'Could not start event extraction.',
      );
    }
  }

  Future<void> cancel() async {
    if (status != AiNoteEventExtractionStatus.generating) return;
    _finalized = true;
    await _subscription?.cancel();
    await _handle?.cancel();
    _subscription = null;
    _handle = null;
    status = AiNoteEventExtractionStatus.cancelled;
    errorMessage = 'Event extraction was cancelled.';
    _notify();
  }

  void updateTitle(String value) => _replaceDraft(title: value);

  void updateDescription(String value) => _replaceDraft(description: value);

  void updateStartDate(DateTime value) =>
      _replaceDraft(startDate: _dateOnly(value));

  void updateEndDate(DateTime value) =>
      _replaceDraft(endDate: _dateOnly(value));

  void updateStartTime(Duration value) => _replaceDraft(startTime: value);

  void updateEndTime(Duration value) => _replaceDraft(endTime: value);

  void updateIsAllDay(bool value) {
    final draft = reviewDraft;
    if (draft == null || status != AiNoteEventExtractionStatus.completed) {
      return;
    }
    reviewDraft = AiEventProposalReviewDraft(
      title: draft.title,
      description: draft.description,
      startDate: draft.startDate,
      startTime: value ? null : draft.startTime,
      endDate: draft.endDate,
      endTime: value ? null : draft.endTime,
      isAllDay: value,
      tags: draft.tags,
      reminder: draft.reminder,
    );
    _notify();
  }

  void updateReminder(EventReminder value) => _replaceDraft(reminder: value);

  void toggleTag(String value) {
    final draft = reviewDraft;
    if (draft == null) return;
    final tags = List<String>.of(draft.tags);
    tags.contains(value) ? tags.remove(value) : tags.add(value);
    _replaceDraft(tags: tags);
  }

  void _replaceDraft({
    String? title,
    String? description,
    DateTime? startDate,
    Duration? startTime,
    DateTime? endDate,
    Duration? endTime,
    bool? isAllDay,
    List<String>? tags,
    EventReminder? reminder,
  }) {
    final draft = reviewDraft;
    if (draft == null || status != AiNoteEventExtractionStatus.completed) {
      return;
    }
    reviewDraft = AiEventProposalReviewDraft(
      title: title ?? draft.title,
      description: description ?? draft.description,
      startDate: startDate ?? draft.startDate,
      startTime: startTime ?? draft.startTime,
      endDate: endDate ?? draft.endDate,
      endTime: endTime ?? draft.endTime,
      isAllDay: isAllDay ?? draft.isAllDay,
      tags: List.unmodifiable(tags ?? draft.tags),
      reminder: reminder ?? draft.reminder,
    );
    _notify();
  }

  void _complete(String output) {
    try {
      proposal = AiEventProposalParser.parse(output);
      final event = proposal!.event;
      if (event == null) {
        reviewDraft = null;
        originallyMissingFields = const {};
      } else {
        reviewDraft = AiEventProposalReviewDraft(
          title: event.title,
          description: event.description,
          startDate: _parseDate(event.startDate),
          startTime: _parseTime(event.startTime),
          endDate: _parseDate(event.endDate),
          endTime: _parseTime(event.endTime),
          isAllDay: event.isAllDay,
        );
        originallyMissingFields = {
          if (event.startDate == null) AiEventReviewField.startDate,
          if (event.startTime == null && event.isAllDay != true)
            AiEventReviewField.startTime,
          if (event.endDate == null) AiEventReviewField.endDate,
          if (event.endTime == null && event.isAllDay != true)
            AiEventReviewField.endTime,
          if (event.isAllDay == null) AiEventReviewField.isAllDay,
        };
      }
      _finish(AiNoteEventExtractionStatus.completed, null);
    } on AiEventProposalFormatException catch (error) {
      _finish(AiNoteEventExtractionStatus.failed, error.message);
    }
  }

  void _finish(AiNoteEventExtractionStatus nextStatus, String? message) {
    if (_finalized) return;
    _finalized = true;
    status = nextStatus;
    errorMessage = message;
    _handle = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static DateTime? _parseDate(String? value) {
    if (value == null) return null;
    final parts = value.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  static Duration? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':').map(int.parse).toList();
    return Duration(hours: parts[0], minutes: parts[1]);
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    if (!_finalized) unawaited(_handle?.cancel());
    super.dispose();
  }
}
