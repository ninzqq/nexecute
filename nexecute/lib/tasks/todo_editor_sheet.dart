import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nexecute/models/todo_item.dart';
import 'package:nexecute/repositories/todo_repository.dart';
import 'package:nexecute/shared/adaptive_navigation_shell.dart';
import 'package:nexecute/shared/app_shortcuts.dart';
import 'package:nexecute/shared/bottom_sheet_safe_area.dart';
import 'package:provider/provider.dart';

Future<void> showTodoEditor(BuildContext context, {TodoItem? todo}) {
  if (AppLayoutBreakpoints.fromContext(context) == AppLayoutClass.expanded) {
    return showDialog<void>(
      context: context,
      builder:
          (dialogContext) => Dialog(
            key: const Key('desktop-task-editor-dialog'),
            clipBehavior: Clip.antiAlias,
            insetPadding: const EdgeInsets.all(40),
            child: SizedBox(
              width: 520,
              height: math.min(
                280,
                MediaQuery.sizeOf(dialogContext).height - 80,
              ),
              child: _TodoEditorSheet(todo: todo, desktopPresentation: true),
            ),
          ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: adaptiveSheetConstraints(context),
    builder:
        (context) => BottomSheetSafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: _TodoEditorSheet(todo: todo),
          ),
        ),
  );
}

class _TodoEditorSheet extends StatefulWidget {
  const _TodoEditorSheet({this.todo, this.desktopPresentation = false});

  final TodoItem? todo;
  final bool desktopPresentation;

  @override
  State<_TodoEditorSheet> createState() => _TodoEditorSheetState();
}

class _TodoEditorSheetState extends State<_TodoEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  bool _isSaving = false;

  bool get _isEditing => widget.todo != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo?.title ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppEditorShortcutRegion(
      onSave: _save,
      onCancel: () => Navigator.maybePop(context),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          widget.desktopPresentation ? 24 : 20,
          widget.desktopPresentation ? 24 : 8,
          widget.desktopPresentation ? 24 : 20,
          24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Edit task' : 'New task',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Task',
                  hintText: 'What needs to be done?',
                ),
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Enter a task'
                            : null,
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              if (widget.desktopPresentation)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.maybePop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    _saveButton(),
                  ],
                )
              else
                _saveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _saveButton() {
    return FilledButton.icon(
      onPressed: _isSaving ? null : _save,
      icon:
          _isSaving
              ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : Icon(_isEditing ? Icons.check : Icons.add),
      label: Text(_isEditing ? 'Save changes' : 'Add task'),
    );
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final repository = context.read<TodoRepository>();
      if (widget.todo case final todo?) {
        await repository.updateTitle(todo, _titleController.text);
      } else {
        await repository.addTodo(_titleController.text);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save task: $error')));
    }
  }
}
