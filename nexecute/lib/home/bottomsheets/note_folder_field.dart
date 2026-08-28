import 'package:flutter/material.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/note_folder.dart';

class NoteFolderField extends StatelessWidget {
  const NoteFolderField({
    super.key,
    required this.folderState,
    required this.selectedFolderId,
    required this.onChanged,
  });

  final DataState<List<NoteFolder>> folderState;
  final String? selectedFolderId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final folders = folderState.valueOrNull ?? const <NoteFolder>[];
    final selectedExists = folders.any(
      (folder) => folder.id == selectedFolderId,
    );
    final selectedValue = selectedExists ? selectedFolderId! : '';

    return KeyedSubtree(
      key: const Key('note-folder-field'),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$selectedValue-${folders.length}'),
        initialValue: selectedValue,
        decoration: const InputDecoration(
          labelText: 'Folder',
          prefixIcon: Icon(Icons.folder_outlined),
        ),
        items: [
          const DropdownMenuItem(value: '', child: Text('Quick Notes')),
          for (final folder in folders)
            DropdownMenuItem(value: folder.id, child: Text(folder.name)),
        ],
        onChanged:
            (value) => onChanged(value == null || value.isEmpty ? null : value),
      ),
    );
  }
}
