import 'package:flutter/material.dart';
import 'package:nexecute/home/bottomsheets/delete_button.dart';
import 'package:nexecute/home/bottomsheets/submit_button.dart';
import 'package:nexecute/home/bottomsheets/utils.dart';
import 'package:nexecute/home/bottomsheets/tag_selector.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/home/widgets/item_time_picker.dart';
import 'package:nexecute/home/widgets/note_checklist_editor.dart';
import 'package:nexecute/models/tag.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/repositories/note_repository.dart';
import 'package:nexecute/services/item_conversion_service.dart';
import 'package:provider/provider.dart';
import 'package:nexecute/home/bottomsheets/item_type.dart';

typedef SaveQuicxecCallback =
    Future<void> Function(Quicxec note, bool isExisting);

class ItemEditorSheet extends StatefulWidget {
  final Event? event;
  final Quicxec? quicxec;
  final DateTime? date;
  final bool isEditing;
  final SaveQuicxecCallback? onSaveQuicxec;
  const ItemEditorSheet({
    super.key,
    this.event,
    this.quicxec,
    this.date,
    this.isEditing = false,
    this.onSaveQuicxec,
  });

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
  DateTime? _selectedDate;
  ItemType _type = ItemType.quicxec;
  NoteContentType _noteContentType = NoteContentType.text;
  List<NoteChecklistItem> _checklistItems = [];
  int _checklistIdSeed = 0;
  List<String> _tags = [];
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
      _type = ItemType.event;
      _tags = widget.event!.tags;
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
      _tags = widget.quicxec!.tags;
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
    setState(() {
      _type = type;
    });
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
    setState(() {
      _checklistItems.removeWhere((item) => item.id == id);
    });
  }

  void _addChecklistItem() {
    setState(() {
      _checklistItems.add(
        NoteChecklistItem(id: _newChecklistItemId(), text: ''),
      );
    });
  }

  Future<void> _submitQuicxec() async {
    var id = '';
    if (widget.quicxec != null) {
      id = widget.quicxec!.id;
    }

    final checklistItems =
        _noteContentType == NoteContentType.checklist
            ? _normalizedChecklistItems
            : const <NoteChecklistItem>[];
    final noteText =
        _noteContentType == NoteContentType.checklist
            ? checklistItems.map((item) => item.text).join('\n')
            : _descriptionController.text;
    final quicxec = Quicxec(
      id: id,
      title: _titleController.text.trim(),
      text: noteText,
      created: _startTime,
      tags: _tags,
      trashed: false,
      contentType: _noteContentType,
      checklistItems: checklistItems,
    );
    final isExisting = widget.quicxec?.id.isNotEmpty == true;

    if (widget.onSaveQuicxec case final onSave?) {
      await onSave(quicxec, isExisting);
    } else if (isExisting) {
      await context.read<NoteRepository>().updateNote(
        quicxec,
        text: noteText,
        title: quicxec.title,
        tags: quicxec.tags,
        contentType: _noteContentType,
        checklistItems: checklistItems,
      );
    } else {
      await context.read<NoteRepository>().addNote(quicxec);
    }
  }

  Future<void> _submitEvent() async {
    var id = '';
    if (widget.event != null) {
      id = widget.event!.id;
    }

    final event = Event(
      id: id,
      title: _titleController.text,
      description: _descriptionController.text,
      startTime: _startTime,
      endTime: _endTime,
      isAllDay: _isAllDay,
      tags: _tags,
    );

    if (widget.event?.id.isNotEmpty == true) {
      await context.read<EventRepository>().updateEvent(
        event,
        title: _titleController.text,
        description: _descriptionController.text,
        startTime: _startTime,
        endTime: _endTime,
        isAllDay: _isAllDay,
        tags: _tags,
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

  @override
  Widget build(BuildContext context) {
    List<String> tags = context.watch<Tags>().tags;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DeleteButton(quicxec: widget.quicxec, event: widget.event),
                const Spacer(),
                SegmentedButton<ItemType>(
                  segments: const [
                    ButtonSegment(
                      value: ItemType.event,
                      label: Text('Event'),
                      icon: Icon(Icons.event),
                    ),
                    ButtonSegment(
                      value: ItemType.quicxec,
                      label: Text('Quicxec'),
                      icon: Icon(Icons.note),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (Set<ItemType> newSelection) {
                    onItemTypeChanged(newSelection.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            TextFormField(
              controller: _titleController,
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
            const SizedBox(height: 16.0),
            if (_type == ItemType.quicxec) ...[
              Row(
                children: [
                  Text(
                    'Note format',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const Spacer(),
                  SegmentedButton<NoteContentType>(
                    key: const Key('note-format-selector'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: NoteContentType.text,
                        label: Text('Text'),
                        icon: Icon(Icons.subject_rounded),
                      ),
                      ButtonSegment(
                        value: NoteContentType.checklist,
                        label: Text('Checklist'),
                        icon: Icon(Icons.checklist_rounded),
                      ),
                    ],
                    selected: {_noteContentType},
                    onSelectionChanged:
                        (selection) => _setNoteContentType(selection.first),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (_type == ItemType.quicxec &&
                _noteContentType == NoteContentType.checklist)
              NoteChecklistEditor(
                items: _checklistItems,
                onItemChanged: _updateChecklistItem,
                onItemRemoved: _removeChecklistItem,
                onItemAdded: _addChecklistItem,
              )
            else
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: _type != ItemType.quicxec ? 3 : 9,
              ),
            const SizedBox(height: 8.0),
            if (_type != ItemType.quicxec) ...[
              Row(
                children: [
                  if (!_isAllDay) ...[
                    const SizedBox(width: 8.0),
                    ItemTimePicker(
                      time: _startTime,
                      icon: Icons.access_time,
                      onTimeChanged: (time) {
                        setState(() {
                          _startTime = time;
                          if (time.isAfter(_endTime)) {
                            _endTime = time.add(const Duration(hours: 1));
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8.0),
                    if (_type != ItemType.quicxec) ...[
                      const Icon(Icons.arrow_right_alt),
                      const SizedBox(width: 16.0),
                      ItemTimePicker(
                        time: _endTime,
                        icon: Icons.access_time,
                        onTimeChanged: (time) {
                          setState(() {
                            _endTime = time;
                          });
                        },
                      ),
                    ],
                  ],
                ],
              ),
              Row(
                children: [
                  const SizedBox(width: 8.0),
                  const Icon(Icons.calendar_today),
                  const SizedBox(width: 8.0),
                  TextButton(
                    onPressed: () async {
                      _selectedDate = await showDatePicker(
                        locale: const Locale('fi', 'FI'),
                        context: context,
                        initialDate: _startTime,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 3650),
                        ),
                      );
                      if (_selectedDate != null) {
                        setState(() {
                          _startTime = combineDateAndTime(
                            _selectedDate!,
                            _startTime,
                          );
                          if (_startTime.isAfter(_endTime)) {
                            _endTime = _startTime.add(const Duration(hours: 1));
                          }
                        });
                      }
                    },
                    child: Text(formatDate(_selectedDate ?? _startTime)),
                  ),
                  const SizedBox(width: 8.0),
                  const Icon(Icons.arrow_right_alt),
                  const SizedBox(width: 16),
                  const Icon(Icons.calendar_today),
                  const SizedBox(width: 8.0),
                  TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endTime,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() {
                          _endTime = combineDateAndTime(date, _endTime);
                        });
                      }
                    },
                    child: Text(formatDate(_endTime)),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('All day'),
                      value: _isAllDay,
                      checkColor: Theme.of(context).colorScheme.onPrimary,
                      onChanged: (bool? value) {
                        setState(() {
                          _isAllDay = value ?? false;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8.0),
            TagSelector(
              tags: tags,
              selectedTags: _tags,
              onTagToggled: (tag) {
                setState(() {
                  if (!_tags.contains(tag)) {
                    _tags.add(tag);
                  } else {
                    _tags.remove(tag);
                  }
                });
              },
            ),
            const SizedBox(height: 8.0),
            SubmitButton(
              onPressed: _isSaving ? null : _submit,
              isEditing: widget.isEditing,
              isLoading: _isSaving,
            ),
            const SizedBox(height: 8.0),
          ],
        ),
      ),
    );
  }
}
