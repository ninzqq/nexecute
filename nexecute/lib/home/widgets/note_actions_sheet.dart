import 'package:flutter/material.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/themes.dart';

class NoteActionsSheet extends StatelessWidget {
  const NoteActionsSheet({
    super.key,
    required this.note,
    required this.onToggleTrash,
    this.folderName,
    this.onExtractTasks,
    this.onMove,
    this.onDelete,
  });

  final Quicxec note;
  final VoidCallback onToggleTrash;
  final String? folderName;
  final VoidCallback? onExtractTasks;
  final VoidCallback? onMove;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appPalette;
    final title =
        note.title.trim().isEmpty ? 'Untitled note' : note.title.trim();

    return SingleChildScrollView(
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
          if (onExtractTasks case final onExtractTasks?) ...[
            _NoteActionTile(
              icon: Icons.auto_awesome_outlined,
              label: 'Propose tasks with AI',
              description: 'Preview this note before sending it',
              color: palette.primary,
              onTap: onExtractTasks,
            ),
            const SizedBox(height: 10),
          ],
          if (onMove case final onMove?) ...[
            _NoteActionTile(
              icon: Icons.drive_file_move_outline,
              label: 'Move to folder',
              description: folderName ?? 'Quick Notes',
              color: palette.primary,
              onTap: onMove,
            ),
            const SizedBox(height: 10),
          ],
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
