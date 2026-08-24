import 'package:flutter/material.dart';
import 'package:nexecute/home/bottomsheets/item_editor.dart';
import 'package:nexecute/home/widgets/taglistitem.dart';
import 'package:nexecute/models/tag.dart';
import 'package:nexecute/services/services.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/themes.dart';

class QuicxecItem extends StatelessWidget {
  final Quicxec quicxec;
  const QuicxecItem({super.key, required this.quicxec});

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (sheetContext) => _NoteActionsSheet(
            note: quicxec,
            onToggleTrash: () => _toggleTrash(context, sheetContext),
            onDelete:
                quicxec.trashed
                    ? () => _deletePermanently(context, sheetContext)
                    : null,
          ),
    );
  }

  Future<void> _toggleTrash(
    BuildContext context,
    BuildContext sheetContext,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(sheetContext).pop();

    try {
      await FirestoreService().moveCurrentlyOpenQuicxec(quicxec);
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
      await FirestoreService().permanentlyDeleteSingleQuicxec(quicxec);
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
            onTap: () {
              showItemEditor(context, quicxec: quicxec, isEditing: true);
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quicxec.title,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 1,
                  ),
                  Expanded(
                    child: Text(
                      quicxec.text,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  SizedBox(
                    height: 32,
                    child: Row(
                      children: [
                        Flexible(
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: quicxec.tags.length,
                            itemBuilder: (BuildContext context, int index) {
                              return TagListItem(
                                tag: Tag(name: quicxec.tags[index]),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteActionsSheet extends StatelessWidget {
  const _NoteActionsSheet({
    required this.note,
    required this.onToggleTrash,
    this.onDelete,
  });

  final Quicxec note;
  final VoidCallback onToggleTrash;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appPalette;
    final title =
        note.title.trim().isEmpty ? 'Untitled note' : note.title.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.sticky_note_2_rounded,
                  color: palette.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Note actions',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: palette.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _NoteActionTile(
            icon:
                note.trashed
                    ? Icons.restore_from_trash_rounded
                    : Icons.delete_outline_rounded,
            label: note.trashed ? 'Restore note' : 'Move note to trash',
            description:
                note.trashed
                    ? 'Return this note to your notes'
                    : 'You can restore it later from Trash',
            color: note.trashed ? palette.success : palette.secondary,
            onTap: onToggleTrash,
          ),
          if (onDelete case final onDelete?) ...[
            const SizedBox(height: 10),
            _NoteActionTile(
              icon: Icons.delete_forever_rounded,
              label: 'Delete permanently',
              description: 'This action cannot be undone',
              color: theme.colorScheme.error,
              onTap: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteActionTile extends StatelessWidget {
  const _NoteActionTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: palette.surfaceRaised,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: color.withValues(alpha: 0.28)),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.onSurface.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: palette.onSurface.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
