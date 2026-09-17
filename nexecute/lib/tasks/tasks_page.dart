import 'package:flutter/material.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/todo_item.dart';
import 'package:nexecute/repositories/todo_repository.dart';
import 'package:nexecute/shared/adaptive_navigation_shell.dart';
import 'package:nexecute/shared/data_state_placeholder.dart';
import 'package:nexecute/tasks/todo_editor_sheet.dart';
import 'package:nexecute/tasks/todo_list_utils.dart';
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DataState<List<TodoItem>>>();

    return FocusTraversalGroup(
      child: AdaptiveContentFrame(
        child: switch (state) {
          DataLoading<List<TodoItem>>() => const DataStatePlaceholder(
            presentation: DataStatePresentation.loading,
            title: 'Loading tasks…',
          ),
          DataUnauthenticated<List<TodoItem>>() => const DataStatePlaceholder(
            presentation: DataStatePresentation.unauthenticated,
            message: 'Sign in to access your tasks.',
          ),
          DataFailure<List<TodoItem>>() => const DataStatePlaceholder(
            presentation: DataStatePresentation.failure,
            title: 'Could not load tasks',
          ),
          DataEmpty<List<TodoItem>>(:final value) => _buildTasks(
            context,
            value,
          ),
          DataReady<List<TodoItem>>(:final value) => _buildTasks(
            context,
            value,
          ),
        },
      ),
    );
  }

  Widget _buildTasks(BuildContext context, List<TodoItem> todos) {
    final active = activeTodos(todos);
    final completed = completedTodos(todos);
    final desktop =
        AppLayoutBreakpoints.fromContext(context) == AppLayoutClass.expanded;

    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const PageStorageKey('tasks-page'),
            padding:
                desktop
                    ? const EdgeInsets.fromLTRB(24, 20, 24, 12)
                    : const EdgeInsets.fromLTRB(12, 12, 12, 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: Text(
                  '${active.length} ${active.length == 1 ? 'task' : 'tasks'} open',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (active.isEmpty)
                const _EmptyTasks()
              else
                for (final todo in active)
                  _DismissibleTodo(todo: todo, completed: false),
              const SizedBox(height: 12),
              if (completed.isNotEmpty)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    key: const PageStorageKey('completed-tasks'),
                    initiallyExpanded: false,
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text('Completed (${completed.length})'),
                    children: [
                      const Divider(height: 1),
                      for (final todo in completed)
                        _DismissibleTodo(todo: todo, completed: true),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const _QuickAddTask(),
      ],
    );
  }
}

class _QuickAddTask extends StatefulWidget {
  const _QuickAddTask();

  @override
  State<_QuickAddTask> createState() => _QuickAddTaskState();
}

class _QuickAddTaskState extends State<_QuickAddTask> {
  final _controller = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desktop =
        AppLayoutBreakpoints.fromContext(context) == AppLayoutClass.expanded;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
              desktop
                  ? const EdgeInsets.fromLTRB(24, 8, 24, 20)
                  : const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: TextField(
            key: const Key('quick-add-task-field'),
            controller: _controller,
            readOnly: _isSaving,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Add a task…',
              prefixIcon: const Icon(Icons.add_task_rounded),
              suffixIcon:
                  _isSaving
                      ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                      : IconButton(
                        tooltip: 'Add task',
                        onPressed: _addTask,
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
            ),
            onSubmitted: (_) => _addTask(),
          ),
        ),
      ),
    );
  }

  Future<void> _addTask() async {
    final title = _controller.text.trim();
    if (_isSaving || title.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await context.read<TodoRepository>().addTodo(title);
      if (!mounted) return;
      _controller.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save task: $error')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: 12),
          Text('Nothing to do', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Add a task when something comes up.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _DismissibleTodo extends StatelessWidget {
  const _DismissibleTodo({required this.todo, required this.completed});

  final TodoItem todo;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final desktop =
        AppLayoutBreakpoints.fromContext(context) == AppLayoutClass.expanded;
    final row = _TodoRow(
      todo: todo,
      completed: completed,
      onDelete: desktop ? () => _delete(context) : null,
    );

    if (desktop) {
      return Padding(padding: const EdgeInsets.only(bottom: 6), child: row);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(completed ? 8 : 0, 0, completed ? 8 : 0, 8),
      child: Dismissible(
        key: ValueKey('todo-${todo.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.only(right: 20),
          alignment: Alignment.centerRight,
          child: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
        confirmDismiss: (_) => _delete(context),
        child: row,
      ),
    );
  }

  Future<bool> _delete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<TodoRepository>().deleteTodo(todo);
      if (!messenger.mounted) return true;

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Task deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                await context.read<TodoRepository>().restoreTodo(todo);
              } catch (error) {
                if (!messenger.mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('Could not restore task: $error')),
                );
              }
            },
          ),
        ),
      );
      return true;
    } catch (error) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not delete task: $error')),
        );
      }
      return false;
    }
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({required this.todo, required this.completed, this.onDelete});

  final TodoItem todo;
  final bool completed;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appPalette;
    final desktop =
        AppLayoutBreakpoints.fromContext(context) == AppLayoutClass.expanded;
    final radius = desktop ? 8.0 : 14.0;

    return Opacity(
      opacity: completed ? 0.62 : 1,
      child: DecoratedBox(
        key: ValueKey('todo-surface-${todo.id}'),
        decoration: BoxDecoration(
          color: palette.surfaceRaised,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color:
                completed
                    ? palette.outline.withValues(alpha: 0.65)
                    : palette.outline,
          ),
          boxShadow:
              completed || desktop
                  ? const []
                  : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: () => showTodoEditor(context, todo: todo),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(
                children: [
                  Checkbox(
                    value: completed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    side: BorderSide(
                      color: completed ? palette.success : palette.primary,
                      width: 1.6,
                    ),
                    onChanged:
                        (value) => _setCompleted(context, value ?? false),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      todo.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight:
                            completed ? FontWeight.w400 : FontWeight.w600,
                        decoration:
                            completed ? TextDecoration.lineThrough : null,
                        decorationColor: palette.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Edit task',
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      backgroundColor: palette.primary.withValues(alpha: 0.1),
                      foregroundColor:
                          completed
                              ? palette.onSurface.withValues(alpha: 0.7)
                              : palette.primary,
                    ),
                    onPressed: () => showTodoEditor(context, todo: todo),
                    icon: const Icon(Icons.edit_outlined, size: 19),
                  ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 2),
                    IconButton(
                      tooltip: 'Delete task',
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 19),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setCompleted(BuildContext context, bool value) async {
    try {
      await context.read<TodoRepository>().setCompleted(todo, value);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update task: $error')));
    }
  }
}
