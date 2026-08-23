import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexecute/domain/calendar/gregorian_month_calculator.dart';
import 'package:nexecute/domain/calendar/iso_week_calculator.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/selected_day.dart';
import 'package:nexecute/ui/calendar/month_view.dart';
import 'package:nexecute/ui/calendar/week_view.dart';
import 'package:provider/provider.dart';

enum CalendarViewMode { week, month }

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _weekCalculator = IsoWeekCalculator();
  final _monthCalculator = GregorianMonthCalculator();
  CalendarViewMode _viewMode = CalendarViewMode.month;
  late DateTime _focusedDay;
  late DateTime _selectedDay;

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

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(bottom: 70),
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
            ),
            const Divider(height: 1),
            Expanded(
              child:
                  _viewMode == CalendarViewMode.month
                      ? MonthView(
                        month: month,
                        selectedDay: _selectedDay,
                        events: events,
                        onDaySelected: _selectDay,
                      )
                      : WeekView(
                        week: week,
                        events: events,
                        selectedDay: _selectedDay,
                        onDaySelected: _selectDay,
                      ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrevious() {
    setState(() {
      _focusedDay =
          _viewMode == CalendarViewMode.month
              ? DateTime(_focusedDay.year, _focusedDay.month - 1, 1)
              : _focusedDay.subtract(const Duration(days: 7));
    });
  }

  void _showNext() {
    setState(() {
      _focusedDay =
          _viewMode == CalendarViewMode.month
              ? DateTime(_focusedDay.year, _focusedDay.month + 1, 1)
              : _focusedDay.add(const Duration(days: 7));
    });
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
}

class _CalendarToolbar extends StatelessWidget {
  const _CalendarToolbar({
    required this.title,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final String title;
  final CalendarViewMode viewMode;
  final ValueChanged<CalendarViewMode> onViewModeChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Next',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              TextButton(onPressed: onToday, child: const Text('Today')),
              const Spacer(),
              SegmentedButton<CalendarViewMode>(
                showSelectedIcon: false,
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
        ],
      ),
    );
  }
}
