import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:nexecute/home/widgets/quicxecitem.dart';
import 'package:nexecute/home/widgets/searchbox.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/note_folder.dart';
import 'package:nexecute/models/notes_controller.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/repositories/note_folder_repository.dart';
import 'package:nexecute/shared/data_state_placeholder.dart';
import 'package:provider/provider.dart';

class Quicxecs extends StatefulWidget {
  const Quicxecs({super.key});

  @override
  State<Quicxecs> createState() => _QuicxecsState();
}

class _QuicxecsState extends State<Quicxecs> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noteState = context.watch<DataState<List<Quicxec>>>();

    final content = switch (noteState) {
      DataLoading<List<Quicxec>>() => const DataStatePlaceholder(
        presentation: DataStatePresentation.loading,
        title: 'Loading notes…',
      ),
      DataUnauthenticated<List<Quicxec>>() => const DataStatePlaceholder(
        presentation: DataStatePresentation.unauthenticated,
        message: 'Sign in to access your notes.',
      ),
      DataFailure<List<Quicxec>>() => const DataStatePlaceholder(
        presentation: DataStatePresentation.failure,
        title: 'Could not load notes',
      ),
      DataEmpty<List<Quicxec>>(:final value) => _buildKnowledgeBase(
        context,
        value,
      ),
      DataReady<List<Quicxec>>(:final value) => _buildKnowledgeBase(
        context,
        value,
      ),
    };
    final notesController = context.watch<NotesController>();
    return PopScope(
      canPop: notesController.location == NotesLocation.root,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _openRoot(context);
      },
      child: content,
    );
  }

  Widget _buildKnowledgeBase(BuildContext context, List<Quicxec> allNotes) {
    final folderState = context.watch<DataState<List<NoteFolder>>>();
    final folders = folderState.valueOrNull ?? const <NoteFolder>[];
    final controller = context.watch<NotesController>();
    final activeNotes = allNotes.where((note) => !note.trashed).toList();
    final normalizedQuery = _searchQuery.trim().toLowerCase();

    if (normalizedQuery.isNotEmpty) {
      final searchCandidates = switch (controller.location) {
        NotesLocation.quickNotes => activeNotes.where(
          (note) => _isQuickNote(note, folders),
        ),
        NotesLocation.folder => activeNotes.where(
          (note) => note.folderId == controller.folderId,
        ),
        NotesLocation.root || NotesLocation.allNotes => activeNotes,
      };
      final results =
          searchCandidates
              .where((note) => _matches(note, normalizedQuery))
              .toList()
            ..sort(_recentlyUpdatedFirst);
      return _notesView(
        context,
        title: 'Search results',
        notes: results,
        folders: folders,
        showBack: controller.location != NotesLocation.root,
        emptyTitle: 'No matching notes',
        emptyMessage: 'Try a different search.',
      );
    }

    if (controller.location == NotesLocation.root) {
      return _rootView(context, activeNotes, folders, folderState);
    }

    final selectedFolder = _folderById(folders, controller.folderId);
    if (controller.location == NotesLocation.folder && selectedFolder == null) {
      return Column(
        children: [
          _searchBox(),
          Expanded(
            child: Column(
              children: [
                const Expanded(
                  child: DataStatePlaceholder(
                    presentation: DataStatePresentation.empty,
                    title: 'Folder not found',
                    message: 'It may have been deleted on another device.',
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openRoot(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to notes'),
                ),
                const SizedBox(height: 96),
              ],
            ),
          ),
        ],
      );
    }

    final visibleNotes = switch (controller.location) {
      NotesLocation.quickNotes =>
        activeNotes.where((note) => _isQuickNote(note, folders)).toList(),
      NotesLocation.folder =>
        activeNotes
            .where((note) => note.folderId == controller.folderId)
            .toList(),
      NotesLocation.allNotes => activeNotes.toList(),
      NotesLocation.root => const <Quicxec>[],
    }..sort(_recentlyUpdatedFirst);

    final title = switch (controller.location) {
      NotesLocation.quickNotes => 'Quick Notes',
      NotesLocation.allNotes => 'All Notes',
      NotesLocation.folder => selectedFolder!.name,
      NotesLocation.root => 'Notes',
    };

    return _notesView(
      context,
      title: title,
      notes: visibleNotes,
      folders: folders,
      showBack: true,
      folder: selectedFolder,
      folderTotalNoteCount:
          selectedFolder == null
              ? null
              : allNotes
                  .where((note) => note.folderId == selectedFolder.id)
                  .length,
      emptyTitle:
          controller.location == NotesLocation.quickNotes
              ? 'Quick Notes is empty'
              : 'No notes here yet',
      emptyMessage:
          controller.location == NotesLocation.quickNotes
              ? 'New and unfiled notes appear here.'
              : 'Create a note or move one into this folder.',
    );
  }

  Widget _rootView(
    BuildContext context,
    List<Quicxec> activeNotes,
    List<NoteFolder> folders,
    DataState<List<NoteFolder>> folderState,
  ) {
    final quickCount =
        activeNotes.where((note) => _isQuickNote(note, folders)).length;

    return Column(
      children: [
        _searchBox(),
        Expanded(
          child: ListView(
            key: const Key('notes-knowledge-base-root'),
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
            children: [
              _LocationTile(
                key: const Key('quick-notes-location'),
                icon: Icons.bolt_rounded,
                title: 'Quick Notes',
                subtitle: 'Your inbox for new and unfiled notes',
                count: quickCount,
                onTap: context.read<NotesController>().openQuickNotes,
              ),
              const SizedBox(height: 8),
              _LocationTile(
                key: const Key('all-notes-location'),
                icon: Icons.library_books_outlined,
                title: 'All Notes',
                subtitle: 'Browse your complete knowledge base',
                count: activeNotes.length,
                onTap: context.read<NotesController>().openAllNotes,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Folders',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    key: const Key('create-note-folder'),
                    tooltip: 'New folder',
                    onPressed: () => _createFolder(context, folders),
                    icon: const Icon(Icons.create_new_folder_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (folderState is DataLoading<List<NoteFolder>>)
                const LinearProgressIndicator(minHeight: 2)
              else if (folderState is DataFailure<List<NoteFolder>>)
                const ListTile(
                  leading: Icon(Icons.error_outline_rounded),
                  title: Text('Could not load folders'),
                )
              else if (folders.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text('Create a folder to organize your notes.'),
                  ),
                )
              else
                for (final folder in folders)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      key: ValueKey('note-folder-${folder.id}'),
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(folder.name),
                      trailing: _CountBadge(
                        count:
                            activeNotes
                                .where((note) => note.folderId == folder.id)
                                .length,
                      ),
                      onTap:
                          () => context.read<NotesController>().openFolder(
                            folder.id,
                          ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _notesView(
    BuildContext context, {
    required String title,
    required List<Quicxec> notes,
    required List<NoteFolder> folders,
    required bool showBack,
    required String emptyTitle,
    required String emptyMessage,
    NoteFolder? folder,
    int? folderTotalNoteCount,
  }) {
    return Column(
      children: [
        _searchBox(),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
          child: Row(
            children: [
              if (showBack)
                IconButton(
                  tooltip: 'Back to notes',
                  onPressed: () => _openRoot(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('${notes.length}'),
              if (folder != null)
                PopupMenuButton<_FolderAction>(
                  tooltip: 'Folder actions',
                  onSelected: (action) {
                    switch (action) {
                      case _FolderAction.rename:
                        _renameFolder(context, folder, folders);
                        break;
                      case _FolderAction.delete:
                        _deleteFolder(
                          context,
                          folder,
                          folderTotalNoteCount ?? notes.length,
                        );
                        break;
                    }
                  },
                  itemBuilder:
                      (_) => const [
                        PopupMenuItem(
                          value: _FolderAction.rename,
                          child: Text('Rename folder'),
                        ),
                        PopupMenuItem(
                          value: _FolderAction.delete,
                          child: Text('Delete folder'),
                        ),
                      ],
                ),
            ],
          ),
        ),
        Expanded(
          child:
              notes.isEmpty
                  ? DataStatePlaceholder(
                    presentation: DataStatePresentation.empty,
                    title: emptyTitle,
                    message: emptyMessage,
                  )
                  : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: MasonryGridView.count(
                      padding: const EdgeInsets.only(bottom: 96),
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        return QuicxecItem(
                          quicxec: note,
                          folderName:
                              title == 'All Notes' || title == 'Search results'
                                  ? _folderName(folders, note.folderId)
                                  : null,
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _searchBox() => SearchBox(
    hintText: 'Search notes',
    controller: _searchController,
    onChanged: (value) => setState(() => _searchQuery = value),
  );

  void _openRoot(BuildContext context) {
    _searchController.clear();
    if (mounted) setState(() => _searchQuery = '');
    context.read<NotesController>().openRoot();
  }

  bool _matches(Quicxec note, String query) {
    return note.title.toLowerCase().contains(query) ||
        note.searchableText.toLowerCase().contains(query) ||
        note.tags.any((tag) => tag.toLowerCase().contains(query));
  }

  int _recentlyUpdatedFirst(Quicxec first, Quicxec second) =>
      second.updatedAt.compareTo(first.updatedAt);

  NoteFolder? _folderById(List<NoteFolder> folders, String? id) {
    for (final folder in folders) {
      if (folder.id == id) return folder;
    }
    return null;
  }

  String _folderName(List<NoteFolder> folders, String? folderId) =>
      _folderById(folders, folderId)?.name ?? 'Quick Notes';

  bool _isQuickNote(Quicxec note, List<NoteFolder> folders) =>
      note.folderId == null || _folderById(folders, note.folderId) == null;

  Future<void> _createFolder(
    BuildContext context,
    List<NoteFolder> folders,
  ) async {
    final name = await _folderNameDialog(context, folders: folders);
    if (name == null || !context.mounted) return;
    try {
      await context.read<NoteFolderRepository>().addFolder(name);
    } catch (error) {
      if (!context.mounted) return;
      _showError(context, 'Could not create folder: $error');
    }
  }

  Future<void> _renameFolder(
    BuildContext context,
    NoteFolder folder,
    List<NoteFolder> folders,
  ) async {
    final name = await _folderNameDialog(
      context,
      folders: folders,
      folder: folder,
    );
    if (name == null || !context.mounted) return;
    try {
      await context.read<NoteFolderRepository>().renameFolder(folder.id, name);
    } catch (error) {
      if (!context.mounted) return;
      _showError(context, 'Could not rename folder: $error');
    }
  }

  Future<void> _deleteFolder(
    BuildContext context,
    NoteFolder folder,
    int noteCount,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('Delete ${folder.name}?'),
            content: Text(
              noteCount == 0
                  ? 'The folder will be deleted.'
                  : '$noteCount ${noteCount == 1 ? 'note' : 'notes'} will be moved to Quick Notes.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete folder'),
              ),
            ],
          ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<NoteFolderRepository>().deleteFolder(folder.id);
      if (!context.mounted) return;
      _openRoot(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Folder deleted; notes moved to Quick Notes'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      _showError(context, 'Could not delete folder: $error');
    }
  }

  Future<String?> _folderNameDialog(
    BuildContext context, {
    required List<NoteFolder> folders,
    NoteFolder? folder,
  }) => showDialog<String>(
    context: context,
    builder: (_) => _FolderNameDialog(folders: folders, folder: folder),
  );

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _FolderAction { rename, delete }

class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({required this.folders, this.folder});

  final List<NoteFolder> folders;
  final NoteFolder? folder;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.folder?.name ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Enter a folder name');
      return;
    }
    final duplicate = widget.folders.any(
      (folder) =>
          folder.id != widget.folder?.id &&
          folder.name.toLowerCase() == name.toLowerCase(),
    );
    if (duplicate) {
      setState(() => _errorText = 'A folder with this name already exists');
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.folder == null ? 'New folder' : 'Rename folder'),
      content: TextField(
        key: const Key('note-folder-name-field'),
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Folder name',
          errorText: _errorText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.folder == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: _CountBadge(count: count),
        onTap: onTap,
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Badge(
      label: Text('$count'),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      textColor: Theme.of(context).colorScheme.onPrimaryContainer,
    );
  }
}
