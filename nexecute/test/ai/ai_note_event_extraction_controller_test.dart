import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/models/event_reminder.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  late AiConnectionProfile profile;
  late FakeAiConnectionProfileStore profileStore;

  setUp(() {
    profile = AiConnectionProfile(
      id: 'home',
      name: 'Home AI',
      protocol: AiProtocol.openAiCompatibleChat,
      baseUrl: Uri.parse('https://ai.example.test/v1'),
      modelId: 'local-model',
    );
    profileStore = FakeAiConnectionProfileStore(
      profiles: [profile],
      activeProfileId: profile.id,
    );
  });

  tearDown(() => profileStore.dispose());

  test(
    'requests an event with the fixed reference time outside chat history',
    () async {
      final repository = FakeAiAssistantRepository(
        responseEvents: const [
          AiReasoningDelta('The note gives a specific date and time range.'),
          AiTextDelta(
            '{"schemaVersion":1,"event":{"title":"Dentist","description":"Check-up","startDate":"2026-09-03","startTime":"14:00","endDate":"2026-09-03","endTime":"15:00","isAllDay":false}}',
          ),
          AiResponseCompleted(),
        ],
      );
      final controller = AiNoteEventExtractionController(
        assistantRepository: repository,
        connectionProfileStore: profileStore,
        idFactory: () => 'request-message',
        clock: () => DateTime(2026, 8, 30, 17, 45),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      final preview = controller.buildPrompt(
        noteTitle: 'Appointment',
        noteContent: 'Dentist next Thursday at 14–15.',
      );
      await controller.start(
        noteId: 'note-1',
        noteTitle: 'Appointment',
        noteContent: 'Dentist next Thursday at 14–15.',
      );
      await _flushEvents();

      expect(controller.status, AiNoteEventExtractionStatus.completed);
      expect(
        controller.reasoning,
        'The note gives a specific date and time range.',
      );
      expect(controller.reviewDraft?.title, 'Dentist');
      expect(
        controller.reviewDraft?.reminder,
        EventReminder.fifteenMinutesBefore,
      );
      expect(controller.canContinue, isTrue);
      final request = repository.startedRequests.single;
      expect(request.conversationId, 'note-event-extraction:note-1');
      expect(
        request.systemInstruction,
        AiNoteEventPromptBuilder.systemInstruction,
      );
      expect(request.resolvedSkills, isEmpty);
      expect(request.messages.single.content, preview.userMessage);
      expect(
        request.messages.single.content,
        contains('"localDate":"2026-08-30"'),
      );
      expect(request.messages.single.content, contains('"localTime":"17:45"'));
    },
  );

  test(
    'keeps missing scheduling values visible until locally resolved',
    () async {
      final repository = FakeAiAssistantRepository(
        responseEvents: const [
          AiTextDelta(
            '{"schemaVersion":1,"event":{"title":"Dinner","description":"With Alex","startDate":"2026-09-04","startTime":null,"endDate":null,"endTime":null,"isAllDay":null}}',
          ),
          AiResponseCompleted(),
        ],
      );
      final controller = AiNoteEventExtractionController(
        assistantRepository: repository,
        connectionProfileStore: profileStore,
        clock: () => DateTime(2026, 8, 30, 12),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.start(
        noteId: 'note-1',
        noteTitle: 'Dinner',
        noteContent: 'Dinner with Alex on Friday.',
      );
      await _flushEvents();

      expect(controller.canContinue, isFalse);
      expect(
        controller.reviewDraft?.validationMessage,
        'Choose timed or all-day.',
      );
      expect(
        controller.originallyMissingFields,
        containsAll({
          AiEventReviewField.startTime,
          AiEventReviewField.endDate,
          AiEventReviewField.endTime,
          AiEventReviewField.isAllDay,
        }),
      );

      controller.updateIsAllDay(false);
      controller.updateStartTime(const Duration(hours: 18));
      controller.updateEndDate(DateTime(2026, 9, 4));
      controller.updateEndTime(const Duration(hours: 19, minutes: 30));
      controller.updateTitle(' Dinner with Alex ');
      controller.toggleTag('Personal');
      controller.updateReminder(EventReminder.oneHourBefore);

      expect(controller.canContinue, isTrue);
      expect(controller.reviewDraft?.tags, ['Personal']);
      expect(controller.reviewDraft?.reminder, EventReminder.oneHourBefore);

      controller.updateIsAllDay(true);
      expect(controller.canContinue, isTrue);
      expect(controller.reviewDraft?.startTime, isNull);
      expect(controller.reviewDraft?.endTime, isNull);
    },
  );

  test(
    'supports no-event, malformed-output, and cancellation states',
    () async {
      final noEventRepository = FakeAiAssistantRepository(
        responseEvents: const [
          AiTextDelta('{"schemaVersion":1,"event":null}'),
          AiResponseCompleted(),
        ],
      );
      final noEventController = AiNoteEventExtractionController(
        assistantRepository: noEventRepository,
        connectionProfileStore: profileStore,
      );
      addTearDown(noEventController.dispose);
      await noEventController.initialize();
      await noEventController.start(
        noteId: 'note-1',
        noteTitle: 'Idea',
        noteContent: 'Maybe paint the wall.',
      );
      await _flushEvents();
      expect(noEventController.status, AiNoteEventExtractionStatus.completed);
      expect(noEventController.reviewDraft, isNull);

      final malformedRepository = FakeAiAssistantRepository(
        responseEvents: const [
          AiTextDelta('Create it directly instead.'),
          AiResponseCompleted(),
        ],
      );
      final malformedController = AiNoteEventExtractionController(
        assistantRepository: malformedRepository,
        connectionProfileStore: profileStore,
      );
      addTearDown(malformedController.dispose);
      await malformedController.initialize();
      await malformedController.start(
        noteId: 'note-1',
        noteTitle: 'Idea',
        noteContent: 'Maybe paint the wall.',
      );
      await _flushEvents();
      expect(malformedController.status, AiNoteEventExtractionStatus.failed);
      expect(
        malformedController.errorMessage,
        'The model did not return valid JSON.',
      );

      final stream = StreamController<AiStreamEvent>();
      addTearDown(stream.close);
      final cancellableRepository = FakeAiAssistantRepository(
        responseStreamBuilder: (_) => stream.stream,
      );
      final cancellableController = AiNoteEventExtractionController(
        assistantRepository: cancellableRepository,
        connectionProfileStore: profileStore,
      );
      addTearDown(cancellableController.dispose);
      await cancellableController.initialize();
      await cancellableController.start(
        noteId: 'note-1',
        noteTitle: 'Idea',
        noteContent: 'Maybe paint the wall.',
      );
      await cancellableController.cancel();
      expect(
        cancellableController.status,
        AiNoteEventExtractionStatus.cancelled,
      );
      expect(cancellableRepository.cancellationCount, 1);
    },
  );

  test('retains structured guidance from a response failure', () async {
    final diagnostic = AiDiagnostic(
      kind: AiDiagnosticKind.modelNotFound,
      title: 'Model not found',
      summary: 'The selected model is unavailable.',
      suggestions: const ['Choose an installed model in AI Settings.'],
    );
    final repository = FakeAiAssistantRepository(
      responseEvents: [
        AiResponseFailed(
          error: StateError('private provider detail'),
          message: diagnostic.summary,
          retryable: true,
          diagnostic: diagnostic,
        ),
      ],
    );
    final controller = AiNoteEventExtractionController(
      assistantRepository: repository,
      connectionProfileStore: profileStore,
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.start(
      noteId: 'note-1',
      noteTitle: 'Appointment',
      noteContent: 'Dentist next Thursday.',
    );
    await _flushEvents();

    expect(controller.status, AiNoteEventExtractionStatus.failed);
    expect(controller.diagnostic, same(diagnostic));
    expect(controller.errorMessage, diagnostic.summary);
    expect(repository.startedRequests, hasLength(1));
  });

  test(
    'freezes the preview reference even when the local clock changes',
    () async {
      var clockCalls = 0;
      final times = [DateTime(2026, 3, 29, 1, 55), DateTime(2026, 3, 29, 4, 5)];
      final repository = FakeAiAssistantRepository(
        responseEvents: const [
          AiTextDelta('{"schemaVersion":1,"event":null}'),
          AiResponseCompleted(),
        ],
      );
      final controller = AiNoteEventExtractionController(
        assistantRepository: repository,
        connectionProfileStore: profileStore,
        clock: () => times[clockCalls++],
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      final preview = controller.buildPrompt(
        noteTitle: 'Clock change',
        noteContent: 'Tomorrow.',
      );
      await controller.start(
        noteId: 'note-clock',
        noteTitle: 'Clock change',
        noteContent: 'Tomorrow.',
      );
      await _flushEvents();

      expect(
        repository.startedRequests.single.messages.single.content,
        preview.userMessage,
      );
      expect(preview.userMessage, contains('"localTime":"01:55"'));
      expect(
        repository.startedRequests.single.messages.single.createdAt,
        times[1],
      );
    },
  );
}

Future<void> _flushEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
