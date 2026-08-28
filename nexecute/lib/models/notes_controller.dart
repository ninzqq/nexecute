import 'package:flutter/foundation.dart';

enum NotesLocation { root, quickNotes, allNotes, folder }

class NotesController extends ChangeNotifier {
  NotesLocation _location = NotesLocation.root;
  String? _folderId;

  NotesLocation get location => _location;
  String? get folderId => _folderId;

  String? get creationFolderId =>
      _location == NotesLocation.folder ? _folderId : null;

  void openRoot() => _select(NotesLocation.root);

  void openQuickNotes() => _select(NotesLocation.quickNotes);

  void openAllNotes() => _select(NotesLocation.allNotes);

  void openFolder(String folderId) =>
      _select(NotesLocation.folder, folderId: folderId);

  void _select(NotesLocation location, {String? folderId}) {
    if (_location == location && _folderId == folderId) return;
    _location = location;
    _folderId = folderId;
    notifyListeners();
  }
}
