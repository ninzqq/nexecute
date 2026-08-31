import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexecute/ai/presentation/ai_note_event_extraction_sheet.dart';
import 'package:nexecute/ai/presentation/ai_note_task_extraction_sheet.dart';
import 'package:nexecute/home/bottomsheets/item_editor.dart';
import 'package:nexecute/home/widgets/note_actions_sheet.dart';
import 'package:nexecute/home/widgets/note_card_content.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/note_folder.dart';
import 'package:nexecute/repositories/note_repository.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/repositories/todo_repository.dart';
import 'package:nexecute/shared/bottom_sheet_safe_area.dart';
import 'package:nexecute/shared/adaptive_navigation_shell.dart';
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';

class QuicxecItem extends StatelessWidget {
  const QuicxecItem({super.key, required this.quicxec, this.folderName});

  final Quicxec quicxec;
  final String? folderName;

  void _showActions(BuildContext context) {
    final folderState = context.read<DataState<List<NoteFolder>>>();
    final folders = folderState.valueOrNull ?? const <NoteFolder>[];
    final currentFolderName =
        folders
            .where((folder) => folder.id == quicxec.folderId)
            .map((folder) => folder.name)
            .firstOrNull ??
        'Quick Notes';
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      constraints: adaptiveSheetConstraints(context),
      builder:
          (sheetContext) => BottomSheetSafeArea(
            child: NoteActionsSheet(
              note: quicxec,
              folderName: currentFolderName,
              onExtractEvent:
                  quicxec.trashed
                      ? null
                      : () {
                        Navigator.of(sheetContext).pop();
                        unawaited(_extractEvent(context));
                      },
              onExtractTasks:
                  quicxec.trashed
                      ? null
                      : () {
                        Navigator.of(sheetContext).pop();
                        unawaited(_extractTasks(context));
                      },
              onMove:
                  quicxec.trashed
                      ? null
                      : () => _showMoveSheet(context, sheetContext),
              onToggleTrash: () => _toggleTrash(context, sheetContext),
              onDelete:
                  quicxec.trashed
                      ? () => _deletePermanently(context, sheetContext)
                      : null,
            ),
          ),
    );
  }

  Future<void> _extractEvent(BuildContext context) async {
    final createdEvent = await showAiNoteEventExtractionPreview(
      context,
      note: quicxec,
      onCreate: context.read<EventRepository>().createEvent,
    );
    if (createdEvent == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Event created: ${createdEvent.title}')),
    );
  }

  Future<void> _extractTasks(BuildContext context) async {
    final createdCount = await showAiNoteTaskExtractionPreview(
      context,
      note: quicxec,
      onCreate: context.read<TodoRepository>().createTodos,
    );
    if (createdCount == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$createdCount task${createdCount == 1 ? '' : 's'} created',
        ),
      ),
    );
  }

  Future<void> _showMoveSheet(
    BuildContext context,
    BuildContext actionsSheetContext,
  ) async {
    Navigator.of(actionsSheetContext).pop();
    final folderState = context.read<DataState<List<NoteFolder>>>();
    final folders = folderState.valueOrNull ?? const <NoteFolder>[];
    final destination = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      constraints: adaptiveSheetConstraints(context),
      builder:
          (sheetContext) => BottomSheetSafeArea(
            child: _FolderDestinationSheet(
              folders: folders,
              currentFolderId: quicxec.folderId,
            ),
          ),
    );
    if (destination == null || !context.mounted) return;

    final destinationId = destination.isEmpty ? null : destination;
    if (destinationId == quicxec.folderId) return;
    try {
      await context.read<NoteRepository>().moveNote(quicxec.id, destinationId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note moved')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not move note: $error')));
    }
  }

  Future<void> _toggleTrash(
    BuildContext context,
    BuildContext sheetContext,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(sheetContext).pop();

    try {
      await context.read<NoteRepository>().toggleTrashed(quicxec);
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            quicxec.trashed ? 'Note restored' : 'Note moved to trash',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            quicxec.trashed
                ? 'Could not restore note'
                : 'Could not move note to trash',
          ),
        ),
      );
    }
  }

  Future<void> _deletePermanently(
    BuildContext context,
    BuildContext sheetContext,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(sheetContext).pop();

    try {
      await context.read<NoteRepository>().deletePermanently(quicxec);
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Note permanently deleted')),
      );
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete note')),
      );
    }
  }

  Future<void> _setChecklistItemChecked(
    BuildContext context,
    NoteChecklistItem item,
    bool isChecked,
  ) async {
    try {
      await context.read<NoteRepository>().setChecklistItemChecked(
        quicxec,
        item.id,
        isChecked,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update checklist: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showActions(context),
      child: Hero(
        tag: quicxec.id,
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: context.appPalette.outline),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: InkWell(
            onTap:
                () =>
                    showItemEditor(context, quicxec: quicxec, isEditing: true),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: NoteCardContent(
                note: quicxec,
                folderName: folderName,
                onChecklistItemChanged:
                    (item, isChecked) =>
                        _setChecklistItemChecked(context, item, isChecked),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderDestinationSheet extends StatelessWidget {
  const _FolderDestinationSheet({
    required this.folders,
    required this.currentFolderId,
  });

  final List<NoteFolder> folders;
  final String? currentFolderId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Move note', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.bolt_rounded),
                  title: const Text('Quick Notes'),
                  trailing:
                      currentFolderId == null
                          ? const Icon(Icons.check_rounded)
                          : null,
                  onTap: () => Navigator.pop(context, ''),
                ),
                for (final folder in folders)
                  ListTile(
                    key: ValueKey('move-to-folder-${folder.id}'),
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(folder.name),
                    trailing:
                        currentFolderId == folder.id
                            ? const Icon(Icons.check_rounded)
                            : null,
                    onTap: () => Navigator.pop(context, folder.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
