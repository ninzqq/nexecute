import 'package:flutter/material.dart';
import 'package:nexecute/home/bottomsheets/editor_tag_selector.dart';
import 'package:nexecute/home/bottomsheets/event_schedule_fields.dart';
import 'package:nexecute/home/bottomsheets/item_editor_header.dart';
import 'package:nexecute/home/bottomsheets/item_type.dart';
import 'package:nexecute/home/bottomsheets/note_editor_fields.dart';
import 'package:nexecute/home/bottomsheets/note_folder_field.dart';
import 'package:nexecute/home/bottomsheets/submit_button.dart';
import 'package:nexecute/home/bottomsheets/utils.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/models/event_recurrence.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/note_folder.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/repositories/note_repository.dart';
import 'package:nexecute/services/item_conversion_service.dart';
import 'package:nexecute/shared/app_shortcuts.dart';
import 'package:provider/provider.dart';

typedef SaveQuicxecCallback =
    Future<void> Function(Quicxec note, bool isExisting);

class ItemEditorSheet extends StatefulWidget {
  const ItemEditorSheet({
    super.key,
    this.event,
    this.quicxec,
    this.date,
    this.isEditing = false,
    this.onSaveQuicxec,
    this.desktopPresentation = false,
  });

  final Event? event;
  final Quicxec? quicxec;
  final DateTime? date;
  final bool isEditing;
  final SaveQuicxecCallback? onSaveQuicxec;
  final bool desktopPresentation;

  @override
  State<ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends State<ItemEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 1));
  bool _isAllDay = false;
  EventReminder _eventReminder = EventReminder.none;
  EventRecurrence _eventRecurrence = EventRecurrence.none;
  DateTime? _selectedDate;
  ItemType _type = ItemType.quicxec;
  NoteContentType _noteContentType = NoteContentType.text;
  List<NoteChecklistItem> _checklistItems = [];
  int _checklistIdSeed = 0;
  List<String> _tags = [];
  String? _folderId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController.text = widget.event!.title;
      _descriptionController.text = widget.event!.description;
      _startTime = widget.event!.startTime;
      _endTime = widget.event!.endTime;
      _isAllDay = widget.event!.isAllDay;
      _eventReminder = widget.event!.reminder;
      _eventRecurrence = widget.event!.recurrence;
      _type = ItemType.event;
      _tags = List.of(widget.event!.tags);
    } else if (widget.quicxec != null) {
      _titleController.text = widget.quicxec!.title;
      _descriptionController.text = widget.quicxec!.text;
      _startTime = widget.quicxec!.created;
      _type = ItemType.quicxec;
      _noteContentType = widget.quicxec!.contentType;
      _checklistItems = List.of(widget.quicxec!.checklistItems);
      if (_noteContentType == NoteContentType.checklist &&
          _checklistItems.isEmpty &&
          widget.quicxec!.text.trim().isNotEmpty) {
        _checklistItems = _itemsFromText(widget.quicxec!.text);
      }
      _tags = List.of(widget.quicxec!.tags);
      _folderId = widget.quicxec!.folderId;
    }
    _selectedDate = widget.date;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void onItemTypeChanged(ItemType type) {
    if (type == ItemType.event &&
        _type == ItemType.quicxec &&
        _noteContentType == NoteContentType.checklist) {
      _descriptionController.text = _checklistAsText(includeStatus: true);
    }
    setState(() => _type = type);
  }

  String _newChecklistItemId() {
    return '${DateTime.now().microsecondsSinceEpoch}-${_checklistIdSeed++}';
  }

  List<NoteChecklistItem> _itemsFromText(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    return lines
        .map((line) => NoteChecklistItem(id: _newChecklistItemId(), text: line))
        .toList();
  }

  List<NoteChecklistItem> get _normalizedChecklistItems {
    return _checklistItems
        .where((item) => item.text.trim().isNotEmpty)
        .map((item) => item.copyWith(text: item.text.trim()))
        .toList();
  }

  String _checklistAsText({bool includeStatus = false}) {
    return _normalizedChecklistItems
        .map((item) {
          if (!includeStatus) return item.text;
          return '${item.isChecked ? '☑' : '☐'} ${item.text}';
        })
        .join('\n');
  }

  void _setNoteContentType(NoteContentType type) {
    if (type == _noteContentType) return;

    setState(() {
      if (type == NoteContentType.checklist && _checklistItems.isEmpty) {
        _checklistItems = _itemsFromText(_descriptionController.text);
        if (_checklistItems.isEmpty) {
          _checklistItems = [
            NoteChecklistItem(id: _newChecklistItemId(), text: ''),
          ];
        }
      } else if (type == NoteContentType.text) {
        _descriptionController.text = _checklistAsText();
      }
      _noteContentType = type;
    });
  }

  void _updateChecklistItem(NoteChecklistItem updatedItem) {
    setState(() {
      final index = _checklistItems.indexWhere(
        (item) => item.id == updatedItem.id,
      );
      if (index != -1) _checklistItems[index] = updatedItem;
    });
  }

  void _removeChecklistItem(String id) {
    setState(() => _checklistItems.removeWhere((item) => item.id == id));
  }

  void _addChecklistItem() {
    setState(() {
      _checklistItems.add(
        NoteChecklistItem(id: _newChecklistItemId(), text: ''),
      );
    });
  }

  void _toggleTag(String tag) {
    setState(() {
      _tags.contains(tag) ? _tags.remove(tag) : _tags.add(tag);
    });
  }

  void _setStartTime(DateTime time) {
    setState(() {
      _startTime = time;
      if (time.isAfter(_endTime)) {
        _endTime = time.add(const Duration(hours: 1));
      }
    });
  }

  void _setStartDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _startTime = combineDateAndTime(date, _startTime);
      if (_startTime.isAfter(_endTime)) {
        _endTime = _startTime.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _submitQuicxec() async {
    final folders = context.read<DataState<List<NoteFolder>>>().valueOrNull;
    final resolvedFolderId =
        folders == null || folders.any((folder) => folder.id == _folderId)
            ? _folderId
            : null;
    final checklistItems =
        _noteContentType == NoteContentType.checklist
            ? _normalizedChecklistItems
            : const <NoteChecklistItem>[];
    final noteText =
        _noteContentType == NoteContentType.checklist
            ? checklistItems.map((item) => item.text).join('\n')
            : _descriptionController.text;
    final quicxec = Quicxec(
      id: widget.quicxec?.id ?? '',
      title: _titleController.text.trim(),
      text: noteText,
      created: _startTime,
      tags: _tags,
      folderId: resolvedFolderId,
      trashed: false,
      contentType: _noteContentType,
      checklistItems: checklistItems,
    );
    final isExisting = widget.quicxec?.id.isNotEmpty == true;

    if (widget.onSaveQuicxec case final onSave?) {
      await onSave(quicxec, isExisting);
    } else if (isExisting) {
      await context.read<NoteRepository>().updateNote(
        UpdateNoteCommand.fromNote(quicxec),
      );
    } else {
      await context.read<NoteRepository>().addNote(quicxec);
    }
  }

  Future<void> _submitEvent() async {
    final originalEvent = widget.event;
    final unchangedOccurrenceSchedule =
        originalEvent?.isGeneratedOccurrence == true &&
        _startTime == originalEvent!.startTime &&
        _endTime == originalEvent.endTime;
    final event = Event(
      id: widget.event?.id ?? '',
      title: _titleController.text,
      description: _descriptionController.text,
      startTime:
          unchangedOccurrenceSchedule
              ? originalEvent.seriesStartTime
              : _startTime,
      endTime:
          unchangedOccurrenceSchedule ? originalEvent.seriesEndTime : _endTime,
      isAllDay: _isAllDay,
      tags: _tags,
      reminder: _eventReminder,
      recurrence: _eventRecurrence,
    );

    if (widget.event?.id.isNotEmpty == true) {
      await context.read<EventRepository>().updateEvent(
        UpdateEventCommand.fromEvent(event),
      );
    } else {
      await context.read<EventRepository>().addEvent(event);
    }
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      if (widget.isEditing &&
          widget.quicxec != null &&
          widget.event == null &&
          _type == ItemType.event) {
        await context.read<ItemConversionService>().noteToEvent(
          widget.quicxec!,
        );
      } else if (widget.isEditing &&
          widget.event != null &&
          widget.quicxec == null &&
          _type == ItemType.quicxec) {
        await context.read<ItemConversionService>().eventToNote(widget.event!);
      } else if (_type == ItemType.quicxec) {
        await _submitQuicxec();
      } else {
        await _submitEvent();
      }

      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save ${_type == ItemType.quicxec ? 'note' : 'event'}: $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<Widget> _editorFields(BuildContext context) {
    return [
      ItemEditorHeader(
        title: _editorTitle,
        type: _type,
        event: widget.event,
        note: widget.quicxec,
        onTypeChanged: onItemTypeChanged,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _titleController,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Title',
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (_type == ItemType.event &&
              (value == null || value.trim().isEmpty)) {
            return 'Please enter a title';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      if (_type == ItemType.quicxec)
        NoteEditorFields(
          contentType: _noteContentType,
          descriptionController: _descriptionController,
          checklistItems: _checklistItems,
          onContentTypeChanged: _setNoteContentType,
          onChecklistItemChanged: _updateChecklistItem,
          onChecklistItemRemoved: _removeChecklistItem,
          onChecklistItemAdded: _addChecklistItem,
        )
      else ...[
        TextFormField(
          controller: _descriptionController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
          minLines: 4,
          maxLines: 8,
        ),
        const SizedBox(height: 8),
        EventScheduleFields(
          startTime: _startTime,
          endTime: _endTime,
          isAllDay: _isAllDay,
          reminder: _eventReminder,
          recurrence: _eventRecurrence,
          selectedStartDate: _selectedDate,
          onStartTimeChanged: _setStartTime,
          onEndTimeChanged: (time) => setState(() => _endTime = time),
          onStartDateChanged: _setStartDate,
          onEndDateChanged:
              (date) =>
                  setState(() => _endTime = combineDateAndTime(date, _endTime)),
          onAllDayChanged: (isAllDay) => setState(() => _isAllDay = isAllDay),
          onReminderChanged:
              (reminder) => setState(() => _eventReminder = reminder),
          onRecurrenceChanged:
              (recurrence) => setState(() => _eventRecurrence = recurrence),
        ),
      ],
      const SizedBox(height: 8),
      if (_type == ItemType.quicxec) ...[
        NoteFolderField(
          folderState: context.watch<DataState<List<NoteFolder>>>(),
          selectedFolderId: _folderId,
          onChanged: (folderId) => setState(() => _folderId = folderId),
        ),
        const SizedBox(height: 8),
      ],
      EditorTagSelector(selectedTags: _tags, onTagToggled: _toggleTag),
      const SizedBox(height: 8),
    ];
  }

  Widget _submitButton() {
    return SubmitButton(
      key: const Key('item-editor-submit-button'),
      onPressed: _isSaving ? null : _submit,
      isEditing: widget.isEditing,
      isLoading: _isSaving,
    );
  }

  String get _editorTitle {
    final editing =
        widget.isEditing ||
        widget.event?.id.isNotEmpty == true ||
        widget.quicxec?.id.isNotEmpty == true;
    final noun = _type == ItemType.event ? 'event' : 'note';
    return '${editing ? 'Edit' : 'New'} $noun';
  }

  Widget _actionBar() {
    if (!widget.desktopPresentation) return _submitButton();

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.maybePop(context),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 120, child: _submitButton()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppEditorShortcutRegion(
      onSave: _submit,
      onCancel: () => Navigator.maybePop(context),
      child: Container(
        key:
            widget.desktopPresentation
                ? const Key('desktop-item-editor-surface')
                : null,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius:
              widget.desktopPresentation
                  ? BorderRadius.circular(12)
                  : const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
        ),
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fields = _editorFields(context);
              if (!constraints.hasBoundedHeight) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...fields,
                      _submitButton(),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      key: const Key('item-editor-fields-scroll-view'),
                      padding: EdgeInsets.fromLTRB(
                        widget.desktopPresentation ? 24 : 16,
                        widget.desktopPresentation ? 24 : 16,
                        widget.desktopPresentation ? 24 : 16,
                        0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: fields,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    key: const Key('item-editor-sticky-actions'),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        top: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        widget.desktopPresentation ? 24 : 16,
                        12,
                        widget.desktopPresentation ? 24 : 16,
                        widget.desktopPresentation ? 16 : 16,
                      ),
                      child: _actionBar(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
