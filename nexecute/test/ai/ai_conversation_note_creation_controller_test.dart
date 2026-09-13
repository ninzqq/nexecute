import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/repositories/note_repository.dart';

void main() {
  final now = DateTime.utc(2026, 9, 13, 12);
  final source =
      AiConversationNoteSource.fromConversation(
        AiConversation(
          id: 'conversation-1',
          title: 'Planning',
          connectionProfileId: 'profile',
          modelId: 'model',
          createdAt: now,
          updatedAt: now,
          messages: [
            AiChatMessage(
              id: 'user-1',
              role: AiMessageRole.user,
              content: 'Plan the release.',
              createdAt: now,
            ),
            AiChatMessage(
              id: 'assistant-1',
              role: AiMessageRole.assistant,
              content: 'Decide a date.',
              createdAt: now,
            ),
          ],
        ),
      )!;

  test(
    'requires valid reviewed values and creates one frozen command',
    () async {
      final submitted = <CreateConversationNoteCommand>[];
      final controller = AiConversationNoteCreationController(
        submit: (command) async {
          submitted.add(command);
          return command.toNote();
        },
        idFactory: () => 'fixed-creation',
        clock: () => now,
      );
      addTearDown(controller.dispose);

      await controller.create(
        source: source,
        draft: const AiConversationNoteReviewDraft(title: ' ', body: 'Text'),
      );
      expect(submitted, isEmpty);
      expect(controller.command, isNull);

      await controller.create(
        source: source,
        draft: const AiConversationNoteReviewDraft(
          title: '  Release plan  ',
          body: '  Decision: October.  ',
        ),
      );
      expect(submitted, hasLength(1));
      expect(controller.status, AiConversationNoteCreationStatus.completed);
      expect(controller.command?.noteId, 'ai-note-fixed-creation');
      expect(controller.command?.sourceConversationId, 'conversation-1');
      expect(controller.command?.sourceMessageIds, ['user-1', 'assistant-1']);
      expect(controller.command?.title, 'Release plan');
      expect(controller.command?.body, 'Decision: October.');
      expect(controller.createdNote?.id, controller.command?.noteId);

      await controller.create(
        source: source,
        draft: const AiConversationNoteReviewDraft(
          title: 'Other',
          body: 'Other',
        ),
      );
      expect(submitted, hasLength(1));
    },
  );

  test('uncertain failure retries the exact same command once', () async {
    final submitted = <CreateConversationNoteCommand>[];
    final pending = Completer<void>();
    var attempts = 0;
    final controller = AiConversationNoteCreationController(
      submit: (command) async {
        submitted.add(command);
        attempts++;
        if (attempts == 1) {
          await pending.future;
          throw StateError('Uncertain response');
        }
        return command.toNote();
      },
      idFactory: () => 'same-id',
      clock: () => now,
    );
    addTearDown(controller.dispose);
    const draft = AiConversationNoteReviewDraft(
      title: 'Release plan',
      body: 'Choose a date.',
    );

    final first = controller.create(source: source, draft: draft);
    expect(controller.status, AiConversationNoteCreationStatus.creating);
    await controller.create(source: source, draft: draft);
    expect(submitted, hasLength(1));
    pending.complete();
    await first;
    expect(controller.status, AiConversationNoteCreationStatus.failed);
    expect(controller.errorMessage, contains('same note ID'));

    await controller.retry();
    expect(controller.status, AiConversationNoteCreationStatus.completed);
    expect(submitted, hasLength(2));
    expect(identical(submitted.first, submitted.last), isTrue);
    await controller.retry();
    expect(submitted, hasLength(2));
  });
}
