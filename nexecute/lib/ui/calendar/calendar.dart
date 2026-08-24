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
  static const _initialPage = 12000;
  static const _pageAnimationDuration = Duration(milliseconds: 280);

  final _weekCalculator = IsoWeekCalculator();
  final _monthCalculator = GregorianMonthCalculator();
  late final PageController _monthPageController;
  late final PageController _weekPageController;
  CalendarViewMode _viewMode = CalendarViewMode.month;
  late DateTime _pageAnchor;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  int _monthPage = _initialPage;
  int _weekPage = _initialPage;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _pageAnchor = DateTime(today.year, today.month, today.day);
    _focusedDay = _pageAnchor;
    _selectedDay = _focusedDay;
    _monthPageController = PageController(initialPage: _initialPage);
    _weekPageController = PageController(initialPage: _initialPage);
  }

  @override
  void dispose() {
    _monthPageController.dispose();
    _weekPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final week = _weekCalculator.fromDate(_weekDateForPage(_weekPage));
    final month = _monthCalculator.fromDate(_monthDateForPage(_monthPage));
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
            onViewModeChanged: _changeViewMode,
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
                  child: KeyedSubtree(
                    key: const Key('calendar-swipe-area'),
                    child: IndexedStack(
                      index: _viewMode == CalendarViewMode.month ? 0 : 1,
                      children: [
                        PageView.builder(
                          controller: _monthPageController,
                          allowImplicitScrolling: true,
                          onPageChanged: _onMonthPageChanged,
                          itemBuilder: (context, page) {
                            final pageMonth = _monthCalculator.fromDate(
                              _monthDateForPage(page),
                            );
                            return KeyedSubtree(
                              key: ValueKey(
                                'month-page-${pageMonth.year}-${pageMonth.month}',
                              ),
                              child: MonthView(
                                month: pageMonth,
                                selectedDay: _selectedDay,
                                events: events,
                                onDaySelected: _selectDay,
                                onEventSelected: _openEvent,
                              ),
                            );
                          },
                        ),
                        PageView.builder(
                          controller: _weekPageController,
                          allowImplicitScrolling: true,
                          onPageChanged: _onWeekPageChanged,
                          itemBuilder: (context, page) {
                            final pageWeek = _weekCalculator.fromDate(
                              _weekDateForPage(page),
                            );
                            return KeyedSubtree(
                              key: ValueKey(
                                'week-page-${pageWeek.year}-${pageWeek.weekNumber}',
                              ),
                              child: WeekView(
                                week: pageWeek,
                                events: events,
                                selectedDay: _selectedDay,
                                onDaySelected: _selectDay,
                                onEventSelected: _openEvent,
                              ),
                            );
                          },
                        ),
                      ],
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
    _activePageController.previousPage(
      duration: _pageAnimationDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _showNext() {
    _activePageController.nextPage(
      duration: _pageAnimationDuration,
      curve: Curves.easeOutCubic,
    );
  }

  PageController get _activePageController =>
      _viewMode == CalendarViewMode.month
          ? _monthPageController
          : _weekPageController;

  void _changeViewMode(CalendarViewMode mode) {
    if (mode == _viewMode) return;

    if (mode == CalendarViewMode.month) {
      final page = _monthPageForDate(_focusedDay);
      _monthPage = page;
      if (_monthPageController.hasClients) {
        _monthPageController.jumpToPage(page);
      }
    } else {
      final page = _weekPageForDate(_focusedDay);
      _weekPage = page;
      if (_weekPageController.hasClients) {
        _weekPageController.jumpToPage(page);
      }
    }

    setState(() => _viewMode = mode);
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
    _animateActivePageToDate(normalized);
    context.read<SelectedDay>().setSelectedDay(normalized);
  }

  void _onMonthPageChanged(int page) {
    setState(() {
      _monthPage = page;
      if (_viewMode == CalendarViewMode.month) {
        _focusedDay = _monthDateForPage(page);
      }
    });
  }

  void _onWeekPageChanged(int page) {
    setState(() {
      _weekPage = page;
      if (_viewMode == CalendarViewMode.week) {
        _focusedDay = _weekDateForPage(page);
      }
    });
  }

  void _animateActivePageToDate(DateTime date) {
    final targetPage =
        _viewMode == CalendarViewMode.month
            ? _monthPageForDate(date)
            : _weekPageForDate(date);
    final currentPage =
        _viewMode == CalendarViewMode.month ? _monthPage : _weekPage;

    if (targetPage == currentPage || !_activePageController.hasClients) return;

    _activePageController.animateToPage(
      targetPage,
      duration: _pageAnimationDuration,
      curve: Curves.easeOutCubic,
    );
  }

  DateTime _monthDateForPage(int page) =>
      DateTime(_pageAnchor.year, _pageAnchor.month + page - _initialPage, 1);

  DateTime _weekDateForPage(int page) {
    final anchorWeekStart = _weekCalculator.fromDate(_pageAnchor).start;
    return DateTime(
      anchorWeekStart.year,
      anchorWeekStart.month,
      anchorWeekStart.day + (page - _initialPage) * 7 + 3,
    );
  }

  int _monthPageForDate(DateTime date) =>
      _initialPage +
      (date.year - _pageAnchor.year) * 12 +
      date.month -
      _pageAnchor.month;

  int _weekPageForDate(DateTime date) {
    final anchorWeek = _weekCalculator.fromDate(_pageAnchor);
    final targetWeek = _weekCalculator.fromDate(date);
    final anchorUtc = DateTime.utc(
      anchorWeek.start.year,
      anchorWeek.start.month,
      anchorWeek.start.day,
    );
    final targetUtc = DateTime.utc(
      targetWeek.start.year,
      targetWeek.start.month,
      targetWeek.start.day,
    );
    return _initialPage + targetUtc.difference(anchorUtc).inDays ~/ 7;
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
