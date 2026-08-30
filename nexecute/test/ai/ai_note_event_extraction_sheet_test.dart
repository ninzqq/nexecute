import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/home/bottomsheets/editor_tag_selector.dart';
import 'package:nexecute/home/bottomsheets/event_reminder_field.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/tag.dart' as app_models;
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';

import '../support/fake_ai_dependencies.dart';

void main() {
  testWidgets('previews the exact note, reference, connection, and model first', (
    tester,
  ) async {
    final dependencies = _Dependencies(
      response:
          '{"schemaVersion":1,"event":{"title":"Dentist","description":"Check-up","startDate":"2026-09-03","startTime":"14:00","endDate":"2026-09-03","endTime":"15:00","isAllDay":false}}',
    );
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(dependencies.app());
    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();

    expect(find.text('Home AI · local-model'), findsOneWidget);
    expect(find.text('Weekend plan'), findsOneWidget);
    expect(find.text('Dentist next Thursday at 14–15.'), findsOneWidget);
    expect(dependencies.repository.startedRequests, isEmpty);

    await tester.tap(find.byKey(const Key('ai-note-event-technical-preview')));
    await tester.pumpAndSettle();
    expect(
      find.text(AiNoteEventPromptBuilder.systemInstruction),
      findsOneWidget,
    );
    expect(find.textContaining('"localDate":"2026-08-30"'), findsOneWidget);
    expect(
      find.textContaining('"content":"Dentist next Thursday'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Exact technical request'));
    await tester.tap(find.text('Exact technical request'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-note-event-send')));
    await tester.pumpAndSettle();

    expect(dependencies.repository.startedRequests, hasLength(1));
    await tester.scrollUntilVisible(
      find.byKey(const Key('ai-note-event-completed')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Review event proposal'), findsOneWidget);
    expect(find.byType(EditorTagSelector), findsOneWidget);
    expect(find.byType(EventReminderField), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('ai-note-event-ready')));
    final readyButton = tester.widget<FilledButton>(
      find.byKey(const Key('ai-note-event-ready')),
    );
    expect(readyButton.onPressed, isNotNull);
    expect(dependencies.reviewedDraft, isNull);

    await tester.tap(find.byKey(const Key('ai-note-event-ready')));
    await tester.pumpAndSettle();
    expect(dependencies.reviewedDraft?.title, 'Dentist');
    expect(dependencies.reviewedDraft?.isComplete, isTrue);
  });

  testWidgets('highlights missing schedule fields and keeps continue disabled', (
    tester,
  ) async {
    final dependencies = _Dependencies(
      response:
          '{"schemaVersion":1,"event":{"title":"Dinner","description":"With Alex","startDate":"2026-09-04","startTime":null,"endDate":null,"endTime":null,"isAllDay":null}}',
    );
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(dependencies.app());
    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-note-event-send')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('ai-note-event-validation')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Choose timed or all-day.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('ai-note-event-end-date')),
      -200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Required — missing from the note'), findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('ai-note-event-ready')));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('ai-note-event-ready')))
          .onPressed,
      isNull,
    );
    expect(dependencies.reviewedDraft, isNull);
  });

  testWidgets('offers retry after malformed output without writing anything', (
    tester,
  ) async {
    final dependencies = _Dependencies(response: 'Do it without JSON.');
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(dependencies.app());
    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-note-event-send')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('ai-note-event-retry-guidance')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('The model did not return valid JSON.'), findsOneWidget);
    expect(
      find.text(
        'Nothing was created. You can retry the request or discard it.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    expect(dependencies.reviewedDraft, isNull);

    await tester.tap(find.byKey(const Key('ai-note-event-send')));
    await tester.pumpAndSettle();
    expect(dependencies.repository.startedRequests, hasLength(2));
  });
}

class _Dependencies {
  _Dependencies({required String response})
    : profileStore = FakeAiConnectionProfileStore(
        profiles: [
          AiConnectionProfile(
            id: 'home',
            name: 'Home AI',
            protocol: AiProtocol.openAiCompatibleChat,
            baseUrl: Uri.parse('https://ai.example.test/v1'),
            modelId: 'local-model',
          ),
        ],
        activeProfileId: 'home',
      ),
      repository = FakeAiAssistantRepository(
        responseEvents: [AiTextDelta(response), const AiResponseCompleted()],
      );

  final FakeAiConnectionProfileStore profileStore;
  final FakeAiAssistantRepository repository;
  AiEventProposalReviewDraft? reviewedDraft;

  Widget app() {
    final note = Quicxec(
      id: 'note-1',
      title: 'Weekend plan',
      text: 'Dentist next Thursday at 14–15.',
      created: DateTime.utc(2026, 8, 29),
    );
    return MultiProvider(
      providers: [
        Provider<AiAssistantRepository>.value(value: repository),
        Provider<AiConnectionProfileStore>.value(value: profileStore),
        Provider<DataState<app_models.Tags>>.value(
          value: DataReady(app_models.Tags(tags: const ['Personal', 'Work'])),
        ),
      ],
      child: MaterialApp(
        theme: AppThemes.forPreset(AppThemePreset.midnight),
        home: Scaffold(
          body: Builder(
            builder:
                (context) => FilledButton(
                  onPressed: () async {
                    reviewedDraft = await showAiNoteEventExtractionPreview(
                      context,
                      note: note,
                      clock: () => DateTime(2026, 8, 30, 17, 45),
                    );
                  },
                  child: const Text('Open preview'),
                ),
          ),
        ),
      ),
    );
  }

  void dispose() => profileStore.dispose();
}
