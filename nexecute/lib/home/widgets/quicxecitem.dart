import 'package:flutter/material.dart';
import 'package:nexecute/home/bottomsheets/item_editor.dart';
import 'package:nexecute/home/widgets/note_actions_sheet.dart';
import 'package:nexecute/home/widgets/note_card_content.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/repositories/note_repository.dart';
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';

class QuicxecItem extends StatelessWidget {
  const QuicxecItem({super.key, required this.quicxec});

  final Quicxec quicxec;

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (sheetContext) => NoteActionsSheet(
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
