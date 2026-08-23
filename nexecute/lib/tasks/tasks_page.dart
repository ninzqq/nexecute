import 'package:flutter/material.dart';
import 'package:nexecute/models/todo_item.dart';
import 'package:nexecute/services/firestore.dart';
import 'package:nexecute/tasks/todo_editor_sheet.dart';
import 'package:nexecute/tasks/todo_list_utils.dart';
import 'package:provider/provider.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final todos = context.watch<List<TodoItem>>();
    final active = activeTodos(todos);
    final completed = completedTodos(todos);

    return ListView(
      key: const PageStorageKey('tasks-page'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
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
    );
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
    return Dismissible(
      key: ValueKey('todo-${todo.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (_) => _delete(context),
      child: _TodoRow(todo: todo, completed: completed),
    );
  }

  Future<bool> _delete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirestoreService().deleteTodo(todo);
      if (!messenger.mounted) return true;

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Task deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                await FirestoreService().restoreTodo(todo);
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
  const _TodoRow({required this.todo, required this.completed});

  final TodoItem todo;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: completed ? 0.62 : 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: Checkbox(
          value: completed,
          onChanged: (value) => _setCompleted(context, value ?? false),
        ),
        title: Text(
          todo.title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            decoration: completed ? TextDecoration.lineThrough : null,
          ),
        ),
        trailing: IconButton(
          tooltip: 'Edit task',
          onPressed: () => showTodoEditor(context, todo: todo),
          icon: const Icon(Icons.edit_outlined),
        ),
        onTap: () => showTodoEditor(context, todo: todo),
      ),
    );
  }

  Future<void> _setCompleted(BuildContext context, bool value) async {
    try {
      await FirestoreService().setTodoCompleted(todo, value);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update task: $error')));
    }
  }
}
