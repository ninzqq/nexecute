import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/domain/calendar/gregorian_month_calculator.dart';
import 'package:nexecute/domain/calendar/iso_week_calculator.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/calendar_settings_controller.dart';
import 'package:nexecute/models/selected_day.dart';
import 'package:nexecute/calendar/bottomsheets/event_details.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/shared/adaptive_navigation_shell.dart';
import 'package:nexecute/shared/app_shortcuts.dart';
import 'package:nexecute/shared/data_state_placeholder.dart';
import 'package:nexecute/themes.dart';
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
  static const _initialPage = 120;
  static const _pageCount = _initialPage * 2 + 1;
  static const _recenterThreshold = 20;
  static const _pageAnimationDuration = Duration(milliseconds: 280);

  final _weekCalculator = IsoWeekCalculator();
  final _monthCalculator = GregorianMonthCalculator();
  late PageController _monthPageController;
  late PageController _weekPageController;
  late final TrackingScrollController _weekTimeScrollController;
  CalendarViewMode _viewMode = CalendarViewMode.month;
  late DateTime _pageAnchor;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  int _monthPage = _initialPage;
  int _weekPage = _initialPage;
  int _pageControllerGeneration = 0;
  EventRepository? _eventRepository;
  CalendarQueryRange? _eventRange;
  Stream<DataState<List<Event>>>? _eventsStream;
  double _agendaExpansion = 0;
  bool _isDraggingAgenda = false;
  Event? _selectedEvent;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _pageAnchor = DateTime(today.year, today.month, today.day);
    _focusedDay = _pageAnchor;
    _selectedDay = _focusedDay;
    _monthPageController = _createPageController();
    _weekPageController = _createPageController();
    _weekTimeScrollController = TrackingScrollController(
      initialScrollOffset: weekInitialScrollOffset,
    );
  }

  @override
  void dispose() {
    _monthPageController.dispose();
    _weekPageController.dispose();
    _weekTimeScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = context.read<EventRepository>();
    if (identical(repository, _eventRepository)) return;

    _eventRepository = repository;
    _refreshEventStream(force: true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DataState<List<Event>>>(
      stream: _eventsStream,
      initialData: const DataLoading<List<Event>>(),
      builder: (context, snapshot) {
        final state =
            snapshot.hasError
                ? DataFailure<List<Event>>(snapshot.error!)
                : snapshot.data ?? const DataLoading<List<Event>>();
        return _buildCalendar(context, state);
      },
    );
  }

  Widget _buildCalendar(BuildContext context, DataState<List<Event>> state) {
    final events = state.valueOrNull ?? const <Event>[];
    final calendarSettings = context.watch<CalendarSettingsController?>();
    final showWeekNumbers = calendarSettings?.showWeekNumbers ?? true;
    final week = _weekCalculator.fromDate(_weekDateForPage(_weekPage));
    final month = _monthCalculator.fromDate(_monthDateForPage(_monthPage));
    final selectedEvents = eventsForDay(events, _selectedDay);
    final selectedEvent = _matchingEvent(events, _selectedEvent);

    return FocusTraversalGroup(
      child: Material(
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
            ),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final layoutClass = AppLayoutBreakpoints.fromContext(context);
                  final hasAgenda =
                      state is DataReady<List<Event>> ||
                      state is DataEmpty<List<Event>>;
                  if (layoutClass.usesCalendarSidePane) {
                    final agendaWidth = math.min(
                      360.0,
                      math.max(280.0, constraints.maxWidth * 0.36),
                    );
                    return Row(
                      key: const Key('calendar-side-by-side-layout'),
                      children: [
                        Expanded(
                          child: _calendarPager(
                            events: events,
                            showWeekNumbers: showWeekNumbers,
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        SizedBox(
                          key: const Key('selected-day-agenda-container'),
                          width: agendaWidth,
                          child:
                              selectedEvent == null
                                  ? _agendaForState(
                                    state,
                                    selectedEvents,
                                    isExpanded: true,
                                    reserveFloatingActionButtonSpace: false,
                                  )
                                  : ColoredBox(
                                    key: const Key(
                                      'calendar-event-details-pane',
                                    ),
                                    color: context.appPalette.chrome,
                                    child: AppCancelShortcutRegion(
                                      onCancel:
                                          () => setState(
                                            () => _selectedEvent = null,
                                          ),
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.all(16),
                                        child: EventDetailsPanel(
                                          event: selectedEvent,
                                          onClose:
                                              () => setState(
                                                () => _selectedEvent = null,
                                              ),
                                          onDeleted:
                                              () => setState(
                                                () => _selectedEvent = null,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                        ),
                      ],
                    );
                  }

                  final compactHeight =
                      hasAgenda
                          ? selectedDayAgendaHeight(selectedEvents.length)
                          : 120.0;
                  final expandedHeight = _expandedAgendaHeight(
                    availableHeight: constraints.maxHeight,
                    compactHeight: compactHeight,
                  );
                  final canExpand =
                      hasAgenda &&
                      selectedEvents.isNotEmpty &&
                      expandedHeight - compactHeight >= 32;
                  final agendaHeight =
                      compactHeight +
                      (expandedHeight - compactHeight) *
                          (canExpand ? _agendaExpansion : 0);

                  return Column(
                    children: [
                      Expanded(
                        child: _calendarPager(
                          events: events,
                          showWeekNumbers: showWeekNumbers,
                        ),
                      ),
                      const Divider(height: 1),
                      AnimatedContainer(
                        key: const Key('selected-day-agenda-container'),
                        duration:
                            _isDraggingAgenda
                                ? Duration.zero
                                : const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        height: agendaHeight,
                        child: _agendaForState(
                          state,
                          selectedEvents,
                          isExpanded: canExpand && _agendaExpansion >= 0.5,
                          onToggleExpanded:
                              canExpand ? _toggleAgendaExpansion : null,
                          onResize:
                              canExpand
                                  ? (delta) => _resizeAgenda(
                                    delta,
                                    expandedHeight - compactHeight,
                                  )
                                  : null,
                          onResizeEnd: canExpand ? _finishResizingAgenda : null,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _calendarPager({
    required List<Event> events,
    required bool showWeekNumbers,
  }) {
    return KeyedSubtree(
      key: const Key('calendar-swipe-area'),
      child: IndexedStack(
        index: _viewMode == CalendarViewMode.month ? 0 : 1,
        children: [
          PageView.builder(
            key: ValueKey('month-pager-$_pageControllerGeneration'),
            controller: _monthPageController,
            allowImplicitScrolling: true,
            onPageChanged: _onMonthPageChanged,
            itemCount: _pageCount,
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
                  showWeekNumbers: showWeekNumbers,
                  selectedDay: _selectedDay,
                  events: events,
                  onDaySelected: _selectDay,
                  onEventSelected: _openEvent,
                ),
              );
            },
          ),
          PageView.builder(
            key: ValueKey('week-pager-$_pageControllerGeneration'),
            controller: _weekPageController,
            allowImplicitScrolling: true,
            onPageChanged: _onWeekPageChanged,
            itemCount: _pageCount,
            itemBuilder: (context, page) {
              final pageWeek = _weekCalculator.fromDate(_weekDateForPage(page));
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
                  timeScrollController: _weekTimeScrollController,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _agendaForState(
    DataState<List<Event>> state,
    List<Event> selectedEvents, {
    required bool isExpanded,
    VoidCallback? onToggleExpanded,
    ValueChanged<double>? onResize,
    ValueChanged<double>? onResizeEnd,
    bool reserveFloatingActionButtonSpace = true,
  }) {
    return switch (state) {
      DataLoading<List<Event>>() => const DataStatePlaceholder(
        presentation: DataStatePresentation.loading,
        title: 'Loading events…',
        message: '',
        compact: true,
      ),
      DataUnauthenticated<List<Event>>() => const DataStatePlaceholder(
        presentation: DataStatePresentation.unauthenticated,
        title: 'Sign in to access events',
        message: '',
        compact: true,
      ),
      DataFailure<List<Event>>() => const DataStatePlaceholder(
        presentation: DataStatePresentation.failure,
        title: 'Could not load events',
        compact: true,
      ),
      DataEmpty<List<Event>>() || DataReady<List<Event>>() => SelectedDayAgenda(
        day: _selectedDay,
        events: selectedEvents,
        isExpanded: isExpanded,
        onToggleExpanded: onToggleExpanded,
        onResize: onResize,
        onResizeEnd: onResizeEnd,
        onEventSelected: _openEvent,
        reserveFloatingActionButtonSpace: reserveFloatingActionButtonSpace,
      ),
    };
  }

  double _expandedAgendaHeight({
    required double availableHeight,
    required double compactHeight,
  }) {
    final minimumCalendarHeight =
        _viewMode == CalendarViewMode.month ? 240.0 : 180.0;
    final preferredFraction = _viewMode == CalendarViewMode.month ? 0.60 : 0.68;
    final maximumHeight = math.max(
      compactHeight,
      availableHeight - minimumCalendarHeight,
    );
    return math.max(
      compactHeight,
      math.min(availableHeight * preferredFraction, maximumHeight),
    );
  }

  void _toggleAgendaExpansion() {
    setState(() {
      _isDraggingAgenda = false;
      _agendaExpansion = _agendaExpansion >= 0.5 ? 0 : 1;
    });
  }

  void _resizeAgenda(double delta, double resizeRange) {
    if (resizeRange <= 0) return;
    setState(() {
      _isDraggingAgenda = true;
      _agendaExpansion = (_agendaExpansion - delta / resizeRange).clamp(
        0.0,
        1.0,
      );
    });
  }

  void _finishResizingAgenda(double velocity) {
    setState(() {
      _isDraggingAgenda = false;
      if (velocity.abs() >= 350) {
        _agendaExpansion = velocity < 0 ? 1 : 0;
      } else {
        _agendaExpansion = _agendaExpansion >= 0.5 ? 1 : 0;
      }
    });
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
    _refreshEventStream();
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
      _selectedEvent = null;
    });
    _animateActivePageToDate(normalized);
    context.read<SelectedDay>().setSelectedDay(normalized);
  }

  void _onMonthPageChanged(int page) {
    final pageDate = _monthDateForPage(page);
    if (_shouldRecenter(page)) {
      _recenterPagesOn(pageDate);
      return;
    }

    setState(() {
      _monthPage = page;
      if (_viewMode == CalendarViewMode.month) {
        _focusedDay = pageDate;
      }
    });
    if (_viewMode == CalendarViewMode.month) _refreshEventStream();
  }

  void _onWeekPageChanged(int page) {
    final pageDate = _weekDateForPage(page);
    if (_shouldRecenter(page)) {
      _recenterPagesOn(pageDate);
      return;
    }

    setState(() {
      _weekPage = page;
      if (_viewMode == CalendarViewMode.week) {
        _focusedDay = pageDate;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _synchronizeWeekTimeScrollPositions();
    });
    if (_viewMode == CalendarViewMode.week) _refreshEventStream();
  }

  PageController _createPageController() =>
      PageController(initialPage: _initialPage, keepPage: false);

  bool _shouldRecenter(int page) =>
      page <= _recenterThreshold || page >= _pageCount - 1 - _recenterThreshold;

  void _recenterPagesOn(DateTime date) {
    final oldMonthController = _monthPageController;
    final oldWeekController = _weekPageController;
    final normalized = DateTime(date.year, date.month, date.day);

    setState(() {
      _pageAnchor = normalized;
      _focusedDay = normalized;
      _monthPage = _initialPage;
      _weekPage = _initialPage;
      _pageControllerGeneration += 1;
      _monthPageController = _createPageController();
      _weekPageController = _createPageController();
    });
    _refreshEventStream();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldMonthController.dispose();
      oldWeekController.dispose();
    });
  }

  void _synchronizeWeekTimeScrollPositions() {
    final source = _weekTimeScrollController.mostRecentlyUpdatedPosition;
    if (source == null) return;

    final offset = source.pixels;
    for (final position in _weekTimeScrollController.positions) {
      if (identical(position, source)) continue;
      final target = offset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - target).abs() > 0.5) position.jumpTo(target);
    }
  }

  void _refreshEventStream({bool force = false}) {
    final repository = _eventRepository;
    if (repository == null) return;

    final range = switch (_viewMode) {
      CalendarViewMode.month => monthQueryRange(
        _monthCalculator.fromDate(_monthDateForPage(_monthPage)),
        _monthCalculator,
      ),
      CalendarViewMode.week => weekQueryRange(
        _weekCalculator.fromDate(_weekDateForPage(_weekPage)),
        _weekCalculator,
      ),
    };
    if (!force && range == _eventRange) return;

    _eventRange = range;
    _eventsStream = repository.watchEvents(range);
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
    if (AppLayoutBreakpoints.fromContext(context).usesCalendarSidePane) {
      setState(() => _selectedEvent = event);
    } else {
      showEventDetails(context, event);
    }
  }

  Event? _matchingEvent(List<Event> events, Event? selectedEvent) {
    if (selectedEvent == null) return null;
    for (final event in events) {
      if (event.id == selectedEvent.id &&
          event.startTime == selectedEvent.startTime) {
        return event;
      }
    }
    for (final event in events) {
      if (event.id == selectedEvent.id) return event;
    }
    return null;
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
    final theme = Theme.of(context);

    return ColoredBox(
      key: const Key('calendar-toolbar'),
      color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: [
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
