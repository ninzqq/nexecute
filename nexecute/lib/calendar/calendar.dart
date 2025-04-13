// Copyright 2019 Aleksander Woźniak
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/calendar/bottomsheets/event_details.dart';
import 'package:nexecute/calendar/widgets/single_event_marker_widget.dart';
import 'package:nexecute/calendar/utils.dart';

class Calendar extends StatefulWidget {
  const Calendar({super.key});

  static const routeName = '/calendar';

  @override
  State<Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<Calendar> {
  late final ValueNotifier<List<Event>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  RangeSelectionMode _rangeSelectionMode =
      RangeSelectionMode
          .toggledOff; // Can be toggled on/off by longpressing a date
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();

    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  List<Event> _getEventsForDay(DateTime day) {
    // Implementation example
    return kEvents[day] ?? [];
  }

  List<Event> _getEventsForRange(DateTime start, DateTime end) {
    // Implementation example
    final days = daysInRange(start, end);

    return [for (final d in days) ..._getEventsForDay(d)];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _rangeStart = null; // Important to clean those
        _rangeEnd = null;
        _rangeSelectionMode = RangeSelectionMode.toggledOff;
      });

      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _selectedDay = null;
      _focusedDay = focusedDay;
      _rangeStart = start;
      _rangeEnd = end;
      _rangeSelectionMode = RangeSelectionMode.toggledOn;
    });

    // `start` or `end` could be null
    if (start != null && end != null) {
      _selectedEvents.value = _getEventsForRange(start, end);
    } else if (start != null) {
      _selectedEvents.value = _getEventsForDay(start);
    } else if (end != null) {
      _selectedEvents.value = _getEventsForDay(end);
    }
  }

  void _onDayLongPressed(DateTime day, DateTime focusedDay) {
    print(day);
  }

  double _setRowHeight() {
    return MediaQuery.of(context).size.height * 0.09;
  }

  Widget _buildEventMarker(
    BuildContext context,
    DateTime day,
    List<Event> events,
  ) {
    int maxEvents = 3;
    return Column(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.033),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 1,
            children: [
              for (final event in events.take(maxEvents))
                SingleEventMarkerWidget(event: event),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            TableCalendar<Event>(
              firstDay: kFirstDay,
              lastDay: kLastDay,
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              rangeStartDay: _rangeStart,
              rangeEndDay: _rangeEnd,
              calendarFormat: _calendarFormat,
              rangeSelectionMode: _rangeSelectionMode,
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              rowHeight: _setRowHeight(),
              daysOfWeekHeight: 20,
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: theme.textTheme.titleSmall!,
                weekendStyle: theme.textTheme.titleSmall!,
              ),
              weekNumbersVisible: true,
              calendarBuilders: CalendarBuilders(
                markerBuilder:
                    (context, day, events) =>
                        _buildEventMarker(context, day, events),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: true,
                outsideTextStyle: theme.textTheme.bodyMedium!.copyWith(
                  color: Colors.white24,
                ),
                weekNumberTextStyle: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.primary,
                ),
                weekendTextStyle: theme.textTheme.bodyMedium!,
                cellMargin: const EdgeInsets.all(2.0),
                cellPadding: const EdgeInsets.only(top: 4.0),
                cellAlignment: Alignment.topCenter,
                tableBorder: TableBorder.all(
                  color: theme.colorScheme.secondary,
                ),
                tablePadding: const EdgeInsets.only(left: 2.0, right: 2.0),
                markerDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                markersAlignment: Alignment.bottomLeft,
                selectedDecoration: BoxDecoration(
                  color: theme.colorScheme.tertiary,
                  shape: BoxShape.rectangle,
                ),
                todayDecoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  shape: BoxShape.rectangle,
                ),
              ),
              onDaySelected: _onDaySelected,
              onRangeSelected: _onRangeSelected,
              onDayLongPressed: _onDayLongPressed,
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                }
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
            ),
            const SizedBox(height: 4.0),
            Expanded(
              child: ValueListenableBuilder<List<Event>>(
                valueListenable: _selectedEvents,
                builder: (context, value, _) {
                  return ListView.builder(
                    itemCount: value.length + 1,
                    itemBuilder:
                        (context, index) =>
                            (index != value.length)
                                ? Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                    vertical: 4.0,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(),
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  child: ListTile(
                                    onTap:
                                        () => showModalBottomSheet(
                                          constraints: BoxConstraints(
                                            maxHeight:
                                                MediaQuery.of(
                                                  context,
                                                ).size.height,
                                            minHeight:
                                                MediaQuery.of(
                                                  context,
                                                ).size.height *
                                                0.3,
                                          ),
                                          context: context,
                                          builder:
                                              (context) =>
                                                  EventDetailsBottomSheet(
                                                    event: value[index],
                                                  ),
                                        ),
                                    title: Text('${value[index]}'),
                                  ),
                                )
                                // Add empty container to make the last item have a bottom margin 
                                // (make the last actual item to show above bottom nav bar)
                                : Container(
                                    height: 100,
                                    color: Colors.transparent,
                                  ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
