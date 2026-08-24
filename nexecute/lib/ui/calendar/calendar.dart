import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexecute/domain/calendar/gregorian_month_calculator.dart';
import 'package:nexecute/domain/calendar/iso_week_calculator.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/selected_day.dart';
import 'package:nexecute/calendar/bottomsheets/event_details.dart';
import 'package:nexecute/ui/calendar/month_view.dart';
import 'package:nexecute/ui/calendar/event_date_utils.dart';
import 'package:nexecute/ui/calendar/selected_day_agenda.dart';
import 'package:nexecute/ui/calendar/week_view.dart';
import 'package:provider/provider.dart';

enum CalendarViewMode { week, month }

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const _swipeThreshold = 48.0;

  final _weekCalculator = IsoWeekCalculator();
  final _monthCalculator = GregorianMonthCalculator();
  CalendarViewMode _viewMode = CalendarViewMode.month;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  double _horizontalDragDistance = 0;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _focusedDay = DateTime(today.year, today.month, today.day);
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final week = _weekCalculator.fromDate(_focusedDay);
    final month = _monthCalculator.fromDate(_focusedDay);
    final events = context.watch<List<Event>>();
    final selectedEvents = eventsForDay(events, _selectedDay);

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          _CalendarToolbar(
            title:
                _viewMode == CalendarViewMode.month
                    ? DateFormat('MMMM yyyy').format(month.start)
                    : 'Week ${week.weekNumber} · ${DateFormat('MMM yyyy').format(week.start)}',
            viewMode: _viewMode,
            onViewModeChanged: (mode) => setState(() => _viewMode = mode),
            onPrevious: _showPrevious,
            onNext: _showNext,
            onToday: _showToday,
            onOpenNavigation: () => Scaffold.maybeOf(context)?.openDrawer(),
          ),
          const Divider(height: 1),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    key: const Key('calendar-swipe-area'),
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) => _horizontalDragDistance = 0,
                    onHorizontalDragUpdate:
                        (details) =>
                            _horizontalDragDistance +=
                                details.primaryDelta ?? 0,
                    onHorizontalDragEnd: (_) => _finishHorizontalSwipe(),
                    onHorizontalDragCancel: () => _horizontalDragDistance = 0,
                    child:
                        _viewMode == CalendarViewMode.month
                            ? MonthView(
                              month: month,
                              selectedDay: _selectedDay,
                              events: events,
                              onDaySelected: _selectDay,
                              onEventSelected: _openEvent,
                            )
                            : WeekView(
                              week: week,
                              events: events,
                              selectedDay: _selectedDay,
                              onDaySelected: _selectDay,
                              onEventSelected: _openEvent,
                            ),
                  ),
                ),
                const Divider(height: 1),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: selectedDayAgendaHeight(selectedEvents.length),
                  child: SelectedDayAgenda(
                    day: _selectedDay,
                    events: selectedEvents,
                    onEventSelected: _openEvent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPrevious() {
    setState(() {
      _focusedDay =
          _viewMode == CalendarViewMode.month
              ? DateTime(_focusedDay.year, _focusedDay.month - 1, 1)
              : DateTime(
                _focusedDay.year,
                _focusedDay.month,
                _focusedDay.day - 7,
              );
    });
  }

  void _showNext() {
    setState(() {
      _focusedDay =
          _viewMode == CalendarViewMode.month
              ? DateTime(_focusedDay.year, _focusedDay.month + 1, 1)
              : DateTime(
                _focusedDay.year,
                _focusedDay.month,
                _focusedDay.day + 7,
              );
    });
  }

  void _finishHorizontalSwipe() {
    final distance = _horizontalDragDistance;
    _horizontalDragDistance = 0;

    if (distance <= -_swipeThreshold) {
      _showNext();
    } else if (distance >= _swipeThreshold) {
      _showPrevious();
    }
  }

  void _showToday() {
    final today = DateTime.now();
    _selectDay(DateTime(today.year, today.month, today.day));
  }

  void _selectDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    setState(() {
      _selectedDay = normalized;
      _focusedDay = normalized;
    });
    context.read<SelectedDay>().setSelectedDay(normalized);
  }

  void _openEvent(Event event) {
    showEventDetails(context, event);
  }
}

class _CalendarToolbar extends StatelessWidget {
  const _CalendarToolbar({
    required this.title,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onOpenNavigation,
  });

  final String title;
  final CalendarViewMode viewMode;
  final ValueChanged<CalendarViewMode> onViewModeChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onOpenNavigation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      key: const Key('calendar-toolbar'),
      color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Open navigation menu',
                  onPressed: onOpenNavigation,
                  icon: const Icon(Icons.menu),
                ),
                const SizedBox(width: 4),
                Text(
                  'Calendar',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Previous',
                  visualDensity: VisualDensity.compact,
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Next',
                  visualDensity: VisualDensity.compact,
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                TextButton(onPressed: onToday, child: const Text('Today')),
                const Spacer(),
                SegmentedButton<CalendarViewMode>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: CalendarViewMode.week,
                      label: Text('Week'),
                    ),
                    ButtonSegment(
                      value: CalendarViewMode.month,
                      label: Text('Month'),
                    ),
                  ],
                  selected: {viewMode},
                  onSelectionChanged:
                      (selection) => onViewModeChanged(selection.first),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
