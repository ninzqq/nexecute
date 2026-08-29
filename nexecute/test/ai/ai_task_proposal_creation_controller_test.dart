import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/repositories/todo_repository.dart';

void main() {
  test('freezes one command and retries that exact command safely', () async {
    final submissions = <CreateTodosCommand>[];
    var shouldFail = true;
    final createdAt = DateTime.utc(2026, 8, 29, 12);
    final controller = AiTaskProposalCreationController(
      idFactory: () => 'creation-1',
      clock: () => createdAt,
      submit: (command) async {
        submissions.add(command);
        if (shouldFail) throw StateError('ambiguous write failure');
      },
    );
    addTearDown(controller.dispose);

    await controller.create(
      sourceNoteId: 'note-1',
      titles: const ['Buy coffee', 'Call Sam'],
    );

    expect(controller.status, AiTaskProposalCreationStatus.failed);
    expect(controller.command!.creationId, 'creation-1');
    expect(controller.command!.sourceNoteId, 'note-1');
    expect(controller.command!.titles, ['Buy coffee', 'Call Sam']);
    expect(controller.command!.createdAt, createdAt);
    expect(submissions, hasLength(1));

    shouldFail = false;
    await controller.retry();

    expect(controller.status, AiTaskProposalCreationStatus.completed);
    expect(submissions, hasLength(2));
    expect(identical(submissions[0], submissions[1]), isTrue);

    await controller.create(
      sourceNoteId: 'note-2',
      titles: const ['Different task'],
    );
    await controller.retry();
    expect(submissions, hasLength(2));
  });

  test('prevents repeated submission while creation is in progress', () async {
    final completion = Completer<void>();
    final submissions = <CreateTodosCommand>[];
    final controller = AiTaskProposalCreationController(
      idFactory: () => 'creation-1',
      submit: (command) {
        submissions.add(command);
        return completion.future;
      },
    );
    addTearDown(controller.dispose);

    final creation = controller.create(
      sourceNoteId: 'note-1',
      titles: const ['Buy coffee'],
    );
    expect(controller.status, AiTaskProposalCreationStatus.creating);

    await controller.create(
      sourceNoteId: 'note-2',
      titles: const ['Duplicate submission'],
    );
    await controller.retry();
    expect(submissions, hasLength(1));

    completion.complete();
    await creation;
    expect(controller.status, AiTaskProposalCreationStatus.completed);
    expect(submissions, hasLength(1));
  });

  test(
    'lets an already submitted write finish after its host is disposed',
    () async {
      final completion = Completer<void>();
      final controller = AiTaskProposalCreationController(
        idFactory: () => 'creation-1',
        submit: (_) => completion.future,
      );

      final creation = controller.create(
        sourceNoteId: 'note-1',
        titles: const ['Buy coffee'],
      );
      controller.dispose();
      completion.complete();

      await creation;
      expect(controller.status, AiTaskProposalCreationStatus.completed);
    },
  );
}
