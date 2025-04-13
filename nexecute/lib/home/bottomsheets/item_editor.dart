import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/home/widgets/item_time_picker.dart';
import 'package:nexecute/services/firestore.dart';

void showItemEditor(
  BuildContext context, {
  Event? event,
  Quicxec? quicxec,
  DateTime? date,
}) {
  showModalBottomSheet(
    isScrollControlled: true,
    isDismissible: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.8,
      minHeight: MediaQuery.of(context).size.height * 0.3,
    ),
    context: context,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: ItemEditorSheet(event: event, quicxec: quicxec, date: date),
      ),
    ),
  );
}

class ItemEditorSheet extends StatefulWidget {
  final Event? event;
  final Quicxec? quicxec;
  final DateTime? date;
  const ItemEditorSheet({
    super.key,
    this.event,
    this.quicxec,
    this.date,
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
  bool _isEvent = true;
  DateTime? _dueDate;
  DateTime? _selectedDate;
  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController.text = widget.event!.title;
      _descriptionController.text = widget.event!.description;
      _startTime = widget.event!.startTime;
      _endTime = widget.event!.endTime;
      _isAllDay = widget.event!.isAllDay;
    } else if (widget.quicxec != null) {
      _titleController.text = widget.quicxec!.title;
      _descriptionController.text = widget.quicxec!.text;
      _startTime = widget.quicxec!.created;
      _dueDate = widget.quicxec!.created;
    }
    _selectedDate = widget.date;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_isEvent) {
        final event = Event(
          title: _titleController.text,
          description: _descriptionController.text,
          startTime: _startTime,
          endTime: _endTime,
          isAllDay: _isAllDay,
        );
        Navigator.pop(context, event);
      } else {
        final quicxec = Quicxec(
          id: widget.quicxec!.id,
          title: _titleController.text,
          text: _descriptionController.text,
          created: _startTime,
          tags: [],
          trashed: false,
        );
        print("************************************************");
        print("quicxec: $quicxec");
        print("************************************************");
        FirestoreService().addNewQuicxec(
          _titleController.text,
          _descriptionController.text,
          [],
          _startTime,
        );
        Navigator.pop(context, quicxec);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Text(
                  widget.event != null ? 'Edit' : 'Add new event',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Event')),
                    ButtonSegment(value: false, label: Text('Task')),
                  ],
                  selected: {_isEvent},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() {
                      _isEvent = newSelection.first;
                    });
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
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16.0),
            Row(children: [
              if (!_isAllDay) ...[
                const SizedBox(width: 8.0),
                ItemTimePicker(
                  time: _startTime,
                  icon: Icons.access_time,
                  onTimeChanged: (time) {
                    setState(() {
                      _startTime = time;
                    });
                  },
                ),
                const SizedBox(width: 8.0),
                if (_isEvent) ...[
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
            ]),
            if (_isEvent) ...[
              Row(children: [
                const SizedBox(width: 8.0),
                const Icon(Icons.calendar_today),
                const SizedBox(width: 8.0),
                TextButton(
                  onPressed: () async {
                    _selectedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (_selectedDate != null) {
                      setState(() {
                        print(_selectedDate);
                        _startTime = DateTime(
                          _selectedDate!.year,
                          _selectedDate!.month,
                          _selectedDate!.day,
                        );
                      });
                    }
                  },
                  child: Text(_formatDate(_selectedDate ?? DateTime.now())),
                ),
                const SizedBox(width: 8.0),
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
              ]),
            ] else ...[
              const SizedBox(height: 8.0),
              Row(
                children: [
                  const SizedBox(width: 8.0),
                  const Icon(Icons.calendar_today),
                  const SizedBox(width: 8.0),
                  TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() {
                          _dueDate = date;
                        });
                      }
                    },
                    child: Text(_dueDate != null
                        ? _formatDate(_dueDate!)
                        : 'Set due date'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year}';
  }
}
