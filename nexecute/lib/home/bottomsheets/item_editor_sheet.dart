import 'package:flutter/material.dart';
import 'package:nexecute/home/bottomsheets/delete_button.dart';
import 'package:nexecute/home/bottomsheets/submit_button.dart';
import 'package:nexecute/home/bottomsheets/utils.dart';
import 'package:nexecute/home/bottomsheets/tag_selector.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/home/widgets/item_time_picker.dart';
import 'package:nexecute/models/tag.dart';
import 'package:nexecute/services/firestore.dart';
import 'package:nexecute/shared/styles.dart';
import 'package:provider/provider.dart';
import 'package:nexecute/home/bottomsheets/item_type.dart';

class ItemEditorSheet extends StatefulWidget {
  final Event? event;
  final Quicxec? quicxec;
  final DateTime? date;
  final bool isEditing;
  const ItemEditorSheet({
    super.key,
    this.event,
    this.quicxec,
    this.date,
    this.isEditing = false,
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
  List<String> _tags = [];

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
    setState(() {
      _type = type;
    });
  }

  void _submitQuicxec(List<Quicxec> quicxecs) {
    if (_formKey.currentState!.validate()) {
      var id = '';
      if (widget.quicxec != null) {
        id = widget.quicxec!.id;
      }

      final quicxec = Quicxec(
        id: id,
        title: _titleController.text,
        text: _descriptionController.text,
        created: _startTime,
        tags: _tags,
        trashed: false,
      );

      if (existingQuicxec(quicxecs, widget.quicxec)) {
        FirestoreService().modifyCurrentlyOpenQuicxec(
          quicxec,
          _descriptionController.text,
          _titleController.text,
          quicxec.tags,
        );
      } else {
        var newQuicxec = Quicxec(
          id: widget.quicxec!.id,
          text: _descriptionController.text,
          title: _titleController.text,
          created: _startTime,
          tags: _tags,
        );
        FirestoreService().addNewQuicxec(newQuicxec);
      }
      Navigator.pop(context);
    }
  }

  void _submitEvent(List<Event> events) {
    if (_formKey.currentState!.validate()) {
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

      if (existingEvent(events, widget.event)) {
        FirestoreService().modifyCurrentlyOpenEvent(
          event,
          _titleController.text,
          _descriptionController.text,
          _startTime,
          _endTime,
          _isAllDay,
          _tags,
        );
      } else {
        FirestoreService().addNewEvent(event);
      }
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Quicxec> quicxecs = context.watch<List<Quicxec>>();
    List<Event> events = context.watch<List<Event>>();
    List<String> tags = context.watch<Tags>().tags;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: drawerBgColor,
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
                DeleteButton(
                  quicxec: widget.quicxec,
                  event: widget.event,
                  quicxecs: quicxecs,
                  events: events,
                ),
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
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16.0),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
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
                          _startTime = DateTime(
                            _selectedDate!.year,
                            _selectedDate!.month,
                            _selectedDate!.day,
                            DateTime.now().hour,
                            DateTime.now().minute,
                            DateTime.now().second,
                          );
                          if (_selectedDate!.isAfter(_endTime)) {
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
                          _endTime = date.add(
                            Duration(
                              hours: _startTime.hour + 1,
                              minutes: _startTime.minute,
                              seconds: _startTime.second,
                            ),
                          );
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
              onPressed: () {
                if (widget.isEditing) {
                  if (widget.quicxec != null &&
                      widget.event == null &&
                      _type == ItemType.event) {
                    FirestoreService().convertQuicxecToEvent(widget.quicxec!);
                  } else if (widget.event != null &&
                      widget.quicxec == null &&
                      _type == ItemType.quicxec) {
                    FirestoreService().convertEventToQuicxec(widget.event!);
                  } else {
                    _type == ItemType.quicxec
                        ? _submitQuicxec(quicxecs)
                        : _submitEvent(events);
                  }
                } else {
                  // Creating a new item
                  _type == ItemType.quicxec
                      ? _submitQuicxec(quicxecs)
                      : _submitEvent(events);
                }
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              isEditing: widget.isEditing,
            ),
            const SizedBox(height: 8.0),
          ],
        ),
      ),
    );
  }
}
