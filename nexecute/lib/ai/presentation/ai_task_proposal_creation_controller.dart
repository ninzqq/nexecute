import 'package:flutter/foundation.dart';
import 'package:nexecute/repositories/todo_repository.dart';
import 'package:uuid/uuid.dart';

typedef AiTaskCreationSubmitter =
    Future<void> Function(CreateTodosCommand command);

enum AiTaskProposalCreationStatus { ready, creating, failed, completed }

class AiTaskProposalCreationController extends ChangeNotifier {
  AiTaskProposalCreationController({
    required AiTaskCreationSubmitter submit,
    String Function()? idFactory,
    DateTime Function()? clock,
  }) : _submit = submit,
       _idFactory = idFactory ?? const Uuid().v4,
       _clock = clock ?? DateTime.now;

  final AiTaskCreationSubmitter _submit;
  final String Function() _idFactory;
  final DateTime Function() _clock;
  bool _disposed = false;

  AiTaskProposalCreationStatus status = AiTaskProposalCreationStatus.ready;
  CreateTodosCommand? command;
  String? errorMessage;

  Future<void> create({
    required String sourceNoteId,
    required List<String> titles,
  }) async {
    if (status != AiTaskProposalCreationStatus.ready) return;
    command = CreateTodosCommand(
      creationId: _idFactory(),
      sourceNoteId: sourceNoteId,
      titles: titles,
      createdAt: _clock(),
    );
    await _submitFrozenCommand();
  }

  Future<void> retry() async {
    if (status != AiTaskProposalCreationStatus.failed || command == null) {
      return;
    }
    await _submitFrozenCommand();
  }

  Future<void> _submitFrozenCommand() async {
    final frozenCommand = command!;
    status = AiTaskProposalCreationStatus.creating;
    errorMessage = null;
    _notify();

    try {
      await _submit(frozenCommand);
      status = AiTaskProposalCreationStatus.completed;
    } catch (_) {
      status = AiTaskProposalCreationStatus.failed;
      errorMessage =
          'Task creation could not be confirmed. Retry uses the same task IDs, '
          'so it cannot create duplicates.';
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
