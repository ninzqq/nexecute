import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexecute/calendar/bottomsheets/event_details.dart';
import 'package:nexecute/home/bottomsheets/item_editor.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/note_folder.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/tag.dart';
import 'package:nexecute/models/todo_item.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/search/search_matcher.dart';
import 'package:nexecute/shared/data_state_placeholder.dart';
import 'package:nexecute/shared/app_shortcuts.dart';
import 'package:nexecute/tasks/todo_editor_sheet.dart';
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';

enum _EventSearchStatus { idle, loading, ready, failure }

Future<void> showDesktopGlobalSearch(
  BuildContext context, {
  VoidCallback? onOpenTags,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final availableHeight = MediaQuery.sizeOf(dialogContext).height - 80;
      return Dialog(
        key: const Key('desktop-global-search-dialog'),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(40),
        child: SizedBox(
          width: 760,
          height: math.min(720, math.max(360, availableHeight)),
          child: UnifiedSearchPage(
            embedded: true,
            onOpenTags:
                onOpenTags == null
                    ? null
                    : () {
                      Navigator.of(dialogContext).pop();
                      onOpenTags();
                    },
          ),
        ),
      );
    },
  );
}

class DesktopGlobalSearchField extends StatelessWidget {
  const DesktopGlobalSearchField({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 280,
      height: 36,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          key: const Key('desktop-global-search-field'),
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Search everything',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppShortcutLabels.search,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UnifiedSearchPage extends StatefulWidget {
  const UnifiedSearchPage({super.key, this.embedded = false, this.onOpenTags});

  final bool embedded;
  final VoidCallback? onOpenTags;

  @override
  State<UnifiedSearchPage> createState() => _UnifiedSearchPageState();
}

class _UnifiedSearchPageState extends State<UnifiedSearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode(debugLabel: 'Unified search');
  Timer? _debounce;
  String _query = '';
  int _searchGeneration = 0;
  List<Event> _events = const [];
  _EventSearchStatus _eventStatus = _EventSearchStatus.idle;
  Object? _eventError;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noteState = context.watch<DataState<List<Quicxec>>>();
    final todoState = context.watch<DataState<List<TodoItem>>>();
    final tagState = context.watch<DataState<Tags>>();
    final folderState = context.watch<DataState<List<NoteFolder>>>();
    final searchBody = Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            widget.embedded ? 16 : 12,
            widget.embedded ? 16 : 12,
            widget.embedded ? 16 : 12,
            8,
          ),
          child: TextField(
            key: const Key('unified-search-field'),
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Search everything',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon:
                  _query.isEmpty
                      ? null
                      : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _controller.clear();
                          _onQueryChanged('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child:
              _query.isEmpty
                  ? const _SearchPrompt()
                  : _buildResults(
                    context,
                    noteState,
                    todoState,
                    tagState,
                    folderState,
                  ),
        ),
      ],
    );

    return Shortcuts(
      shortcuts: AppShortcutBindings.search,
      child: Actions(
        actions: {
          OpenSearchIntent: CallbackAction<OpenSearchIntent>(
            onInvoke: (_) {
              if (isCurrentAppRoute(context)) _focusNode.requestFocus();
              return null;
            },
          ),
          CancelAppIntent: CallbackAction<CancelAppIntent>(
            onInvoke: (_) {
              if (!isCurrentAppRoute(context)) return null;
              if (widget.embedded) {
                Navigator.maybePop(context);
              } else if (_focusNode.hasFocus) {
                _focusNode.unfocus();
              } else {
                Navigator.maybePop(context);
              }
              return null;
            },
          ),
        },
        child: FocusScope(
          autofocus: true,
          child:
              widget.embedded
                  ? Material(
                    key: const Key('desktop-global-search-surface'),
                    color: Theme.of(context).colorScheme.surface,
                    child: searchBody,
                  )
                  : Scaffold(
                    appBar: AppBar(title: const Text('Search')),
                    body: searchBody,
                  ),
        ),
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    DataState<List<Quicxec>> noteState,
    DataState<List<TodoItem>> todoState,
    DataState<Tags> tagState,
    DataState<List<NoteFolder>> folderState,
  ) {
    if (noteState is DataUnauthenticated<List<Quicxec>> ||
        todoState is DataUnauthenticated<List<TodoItem>> ||
        tagState is DataUnauthenticated<Tags> ||
        folderState is DataUnauthenticated<List<NoteFolder>>) {
      return const DataStatePlaceholder(
        presentation: DataStatePresentation.unauthenticated,
        message: 'Sign in to search your data.',
      );
    }

    final folders = folderState.valueOrNull ?? const <NoteFolder>[];
    String folderNameFor(Quicxec note) {
      for (final folder in folders) {
        if (folder.id == note.folderId) return folder.name;
      }
      return 'Quick Notes';
    }

    final notes =
        (noteState.valueOrNull ?? const <Quicxec>[])
            .where(
              (note) =>
                  !note.trashed &&
                  (noteMatchesSearch(note, _query) ||
                      matchesSearchQuery([folderNameFor(note)], _query)),
            )
            .toList()
          ..sort(
            (first, second) => second.updatedAt.compareTo(first.updatedAt),
          );
    final todos =
        (todoState.valueOrNull ?? const <TodoItem>[])
            .where((todo) => todoMatchesSearch(todo, _query))
            .toList()
          ..sort(
            (first, second) => second.updatedAt.compareTo(first.updatedAt),
          );
    final tags =
        (tagState.valueOrNull?.tags ?? const <String>[])
            .where((tag) => tagMatchesSearch(tag, _query))
            .toList()
          ..sort(
            (first, second) =>
                first.toLowerCase().compareTo(second.toLowerCase()),
          );
    final sourcesLoading =
        noteState is DataLoading<List<Quicxec>> ||
        todoState is DataLoading<List<TodoItem>> ||
        tagState is DataLoading<Tags> ||
        folderState is DataLoading<List<NoteFolder>> ||
        _eventStatus == _EventSearchStatus.loading;
    final hasResults =
        _events.isNotEmpty ||
        todos.isNotEmpty ||
        notes.isNotEmpty ||
        tags.isNotEmpty;

    return ListView(
      key: const Key('unified-search-results'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
      children: [
        if (sourcesLoading) const LinearProgressIndicator(minHeight: 2),
        if (!hasResults && !sourcesLoading)
          const Padding(
            padding: EdgeInsets.only(top: 64),
            child: DataStatePlaceholder(
              presentation: DataStatePresentation.empty,
              title: 'No matches',
              message: 'Try another word or phrase.',
            ),
          ),
        if (_events.isNotEmpty)
          _SearchSection(
            title: 'Events',
            count: _events.length,
            children: [
              for (final event in _events)
                ListTile(
                  key: ValueKey('search-event-${event.id}'),
                  leading: const Icon(Icons.event_outlined),
                  title: Text(event.title),
                  subtitle: Text(_eventSubtitle(event)),
                  onTap: () => showEventDetails(context, event),
                ),
            ],
          ),
        if (todos.isNotEmpty)
          _SearchSection(
            title: 'Tasks',
            count: todos.length,
            children: [
              for (final todo in todos)
                ListTile(
                  key: ValueKey('search-todo-${todo.id}'),
                  leading: Icon(
                    todo.isCompleted
                        ? Icons.check_circle_outline_rounded
                        : Icons.radio_button_unchecked_rounded,
                  ),
                  title: Text(
                    todo.title,
                    style: TextStyle(
                      decoration:
                          todo.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Text(todo.isCompleted ? 'Completed' : 'Task'),
                  onTap: () => showTodoEditor(context, todo: todo),
                ),
            ],
          ),
        if (notes.isNotEmpty)
          _SearchSection(
            title: 'Notes',
            count: notes.length,
            children: [
              for (final note in notes)
                ListTile(
                  key: ValueKey('search-note-${note.id}'),
                  leading: Icon(
                    note.isChecklist
                        ? Icons.checklist_rounded
                        : Icons.sticky_note_2_outlined,
                  ),
                  title: Text(
                    note.title.trim().isEmpty ? 'Untitled note' : note.title,
                  ),
                  subtitle: Text(
                    '${folderNameFor(note)} · ${_singleLine(note.contentAsPlainText)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap:
                      () => showItemEditor(
                        context,
                        quicxec: note,
                        isEditing: true,
                      ),
                ),
            ],
          ),
        if (tags.isNotEmpty)
          _SearchSection(
            title: 'Tags',
            count: tags.length,
            children: [
              for (final tag in tags)
                ListTile(
                  key: ValueKey('search-tag-$tag'),
                  leading: const Icon(Icons.label_outline_rounded),
                  title: Text(tag),
                  subtitle: const Text('Tag'),
                  onTap:
                      widget.onOpenTags ??
                      () => Navigator.pushNamed(context, '/tags'),
                ),
            ],
          ),
        if (_eventStatus == _EventSearchStatus.failure)
          _SourceFailure(
            source: 'events',
            error: _eventError,
            onRetry: () => _runEventSearch(_query, ++_searchGeneration),
          ),
        if (noteState is DataFailure<List<Quicxec>>)
          _SourceFailure(source: 'notes', error: noteState.error),
        if (todoState is DataFailure<List<TodoItem>>)
          _SourceFailure(source: 'tasks', error: todoState.error),
        if (tagState is DataFailure<Tags>)
          _SourceFailure(source: 'tags', error: tagState.error),
        if (folderState is DataFailure<List<NoteFolder>>)
          _SourceFailure(source: 'note folders', error: folderState.error),
      ],
    );
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = normalizeSearchQuery(value);
    final generation = ++_searchGeneration;
    setState(() {
      _query = query;
      _events = const [];
      _eventError = null;
      _eventStatus =
          query.isEmpty ? _EventSearchStatus.idle : _EventSearchStatus.loading;
    });
    if (query.isEmpty) return;

    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _runEventSearch(query, generation),
    );
  }

  Future<void> _runEventSearch(String query, int generation) async {
    if (mounted && generation == _searchGeneration) {
      setState(() {
        _eventStatus = _EventSearchStatus.loading;
        _eventError = null;
      });
    }
    try {
      final events = await context.read<EventRepository>().searchEvents(query);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _events = events;
        _eventStatus = _EventSearchStatus.ready;
      });
    } catch (error) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _events = const [];
        _eventError = error;
        _eventStatus = _EventSearchStatus.failure;
      });
    }
  }

  String _eventSubtitle(Event event) {
    final date = DateFormat('d MMM yyyy · HH:mm').format(event.startTime);
    final description = _singleLine(event.description);
    return description.isEmpty ? date : '$date · $description';
  }

  String _singleLine(String text) =>
      text.trim().replaceAll(RegExp(r'\s+'), ' ');
}

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search_rounded,
              size: 52,
              color: palette.secondary,
            ),
            const SizedBox(height: 12),
            Text(
              'Search events, tasks, notes, checklists, and tags',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSection extends StatelessWidget {
  const _SearchSection({
    required this.title,
    required this.count,
    required this.children,
  });

  final String title;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              '$title ($count)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _SourceFailure extends StatelessWidget {
  const _SourceFailure({required this.source, this.error, this.onRetry});

  final String source;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.error_outline_rounded,
        color: Theme.of(context).colorScheme.error,
      ),
      title: Text('Could not search $source'),
      subtitle: error == null ? null : Text('$error', maxLines: 1),
      trailing:
          onRetry == null
              ? null
              : TextButton(onPressed: onRetry, child: const Text('Retry')),
    );
  }
}
