import 'package:flutter/foundation.dart';

enum NotesLocation { root, quickNotes, allNotes, folder }

class NotesController extends ChangeNotifier {
  NotesLocation _location = NotesLocation.root;
  String? _folderId;
  String? _selectedNoteId;
  bool _isCreatingNote = false;
  Future<bool> Function()? _beforeSelectionChange;

  NotesLocation get location => _location;
  String? get folderId => _folderId;
  String? get selectedNoteId => _selectedNoteId;
  bool get isCreatingNote => _isCreatingNote;

  String? get creationFolderId =>
      _location == NotesLocation.folder ? _folderId : null;

  void openRoot() => _select(NotesLocation.root);

  void openQuickNotes() => _select(NotesLocation.quickNotes);

  void openAllNotes() => _select(NotesLocation.allNotes);

  void openFolder(String folderId) =>
      _select(NotesLocation.folder, folderId: folderId);

  void selectNote(String noteId) {
    if (_selectedNoteId == noteId && !_isCreatingNote) return;
    _selectedNoteId = noteId;
    _isCreatingNote = false;
    notifyListeners();
  }

  void setSelectionGuard(Future<bool> Function()? guard) {
    _beforeSelectionChange = guard;
  }

  Future<void> requestSelectNote(String noteId) async {
    if (_selectedNoteId == noteId && !_isCreatingNote) return;
    if (await _canChangeSelection()) selectNote(noteId);
  }

  Future<void> requestOpenNewNote() async {
    if (await _canChangeSelection()) openNewNote();
  }

  Future<void> requestClearNoteSelection() async {
    if (await _canChangeSelection()) clearNoteSelection();
  }

  Future<bool> requestOpenRoot() async {
    if (!await _canChangeSelection()) return false;
    if (_location == NotesLocation.root) {
      clearNoteSelection();
    } else {
      openRoot();
    }
    return true;
  }

  Future<bool> _canChangeSelection() async =>
      await _beforeSelectionChange?.call() ?? true;

  void openNewNote() {
    if (_location == NotesLocation.root) _location = NotesLocation.allNotes;
    _selectedNoteId = null;
    _isCreatingNote = true;
    notifyListeners();
  }

  void clearNoteSelection() {
    if (_selectedNoteId == null && !_isCreatingNote) return;
    _selectedNoteId = null;
    _isCreatingNote = false;
    notifyListeners();
  }

  void _select(NotesLocation location, {String? folderId}) {
    if (_location == location && _folderId == folderId) return;
    _location = location;
    _folderId = folderId;
    _selectedNoteId = null;
    _isCreatingNote = false;
    notifyListeners();
  }
}
