import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/calendar/bottomsheets/event_details.dart';
import 'package:nexecute/domain/calendar/calendar_display_event.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/home/bottomsheets/item_editor_sheet.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/models/event_recurrence.dart';
import 'package:nexecute/models/selected_day.dart';
import 'package:nexecute/models/tag.dart' as models;
import 'package:nexecute/repositories/calendar_read_source.dart';
import 'package:nexecute/repositories/event_repository.dart';
import 'package:nexecute/repositories/google_calendar_source.dart';
import 'package:nexecute/themes.dart';
import 'package:nexecute/ui/calendar/calendar.dart';
import 'package:nexecute/ui/calendar/selected_day_agenda.dart';
import 'package:provider/provider.dart';

import 'support/fake_event_repository.dart';

void main() {
  test('agenda height grows with events and remains capped', () {
    expect(selectedDayAgendaHeight(0), 120);
    expect(selectedDayAgendaHeight(1), 120);
    expect(selectedDayAgendaHeight(10), 232);
  });

  testWidgets('selected-day agenda expands by tapping or dragging its handle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final events = List.generate(
      8,
      (index) => Event(
        id: 'event-$index',
        title: 'Event ${index + 1}',
        startTime: DateTime(now.year, now.month, now.day, 8 + index),
        endTime: DateTime(now.year, now.month, now.day, 9 + index),
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<EventRepository>.value(
            value: FakeEventRepository(events: events),
          ),
          Provider<CalendarReadSource>(
            create:
                (context) => CompositeCalendarReadSource(
                  nativeEventRepository: context.read<EventRepository>(),
                ),
          ),
          ChangeNotifierProvider(create: (_) => SelectedDay()),
        ],
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: const CalendarPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final agenda = find.byKey(const Key('selected-day-agenda-container'));
    final handle = find.byKey(const Key('agenda-resize-handle'));
    final compactHeight = tester.getSize(agenda).height;

    expect(compactHeight, 232);
    expect(find.byTooltip('Expand events · drag to resize'), findsOneWidget);

    await tester.tap(handle);
    await tester.pumpAndSettle();

    final expandedHeight = tester.getSize(agenda).height;
    expect(expandedHeight, greaterThan(compactHeight + 100));
    expect(find.byTooltip('Collapse events · drag to resize'), findsOneWidget);

    await tester.tap(handle);
    await tester.pumpAndSettle();
    expect(tester.getSize(agenda).height, compactHeight);

    final drag = await tester.startGesture(tester.getCenter(handle));
    await drag.moveBy(const Offset(0, -20));
    await tester.pump();
    await drag.moveBy(const Offset(0, -250));
    await tester.pump();

    expect(tester.getSize(agenda).height, greaterThan(compactHeight));

    await drag.up();
    await tester.pumpAndSettle();
    expect(tester.getSize(agenda).height, expandedHeight);
  });

  testWidgets('opens a selected-day event for viewing and editing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final event = Event(
      id: 'event-1',
      title: 'Planning session',
      description: 'Prepare the monthly plan',
      startTime: DateTime(now.year, now.month, now.day, 9),
      endTime: DateTime(now.year, now.month, now.day, 10),
      tags: const ['Work'],
      reminder: EventReminder.none,
      recurrence: EventRecurrence.yearly,
      recurrenceSeriesStartTime: DateTime(now.year - 1, now.month, now.day, 9),
      recurrenceSeriesEndTime: DateTime(now.year - 1, now.month, now.day, 10),
    );

    final repository = FakeEventRepository(events: [event]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<EventRepository>.value(value: repository),
          Provider<CalendarReadSource>(
            create:
                (context) => CompositeCalendarReadSource(
                  nativeEventRepository: context.read<EventRepository>(),
                ),
          ),
          Provider<DataState<models.Tags>>.value(
            value: DataEmpty(models.Tags()),
          ),
          ChangeNotifierProvider(create: (_) => SelectedDay()),
        ],
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: const CalendarPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('selected-day-agenda')), findsOneWidget);
    expect(find.byKey(const ValueKey('agenda-event-event-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agenda-event-event-1')));
    await tester.pumpAndSettle();

    expect(find.byType(EventDetailsBottomSheet), findsOneWidget);
    expect(
      find.byKey(const Key('event-details-schedule-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('event-details-description-card')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('event-details-tags')), findsOneWidget);
    expect(find.text('Edit event'), findsOneWidget);
    expect(find.text('Delete event'), findsOneWidget);
    expect(find.text('Prepare the monthly plan'), findsOneWidget);
    expect(find.text('Repeats yearly'), findsOneWidget);
    expect(
      tester.getSize(find.byType(EventDetailsBottomSheet)).height,
      lessThan(1200 * 0.6),
    );

    await tester.tap(find.byTooltip('Edit event'));
    await tester.pumpAndSettle();

    expect(find.byType(ItemEditorSheet), findsOneWidget);
    expect(find.text('No reminder'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);

    await tester.tap(find.text('No reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 minutes before').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Update'));
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(
      repository.updateCommand?.reminder,
      EventReminder.fifteenMinutesBefore,
    );
    expect(repository.updateCommand?.recurrence, EventRecurrence.yearly);
    expect(
      repository.updateCommand?.startTime,
      DateTime(now.year - 1, now.month, now.day, 9),
    );

    expect(find.byType(EventDetailsBottomSheet), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.byType(EventDetailsBottomSheet), findsNothing);
    expect(find.byKey(const Key('selected-day-agenda')), findsOneWidget);
  });

  testWidgets('shows event details in the expanded calendar side pane', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final event = Event(
      id: 'desktop-event',
      title: 'Desktop planning',
      description: 'Details stay beside the calendar',
      startTime: DateTime(now.year, now.month, now.day, 13),
      endTime: DateTime(now.year, now.month, now.day, 14),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<EventRepository>.value(
            value: FakeEventRepository(events: [event]),
          ),
          Provider<CalendarReadSource>(
            create:
                (context) => CompositeCalendarReadSource(
                  nativeEventRepository: context.read<EventRepository>(),
                ),
          ),
          Provider<DataState<models.Tags>>.value(
            value: DataEmpty(models.Tags()),
          ),
          ChangeNotifierProvider(create: (_) => SelectedDay()),
        ],
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: const CalendarPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('agenda-event-desktop-event')));
    await tester.pumpAndSettle();

    expect(find.byType(EventDetailsBottomSheet), findsNothing);
    expect(find.byKey(const Key('calendar-event-details-pane')), findsOne);
    expect(
      find.byKey(const Key('event-details-schedule-card')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('event-details-actions')), findsOneWidget);
    expect(find.text('Details stay beside the calendar'), findsOneWidget);

    final layoutRect = tester.getRect(
      find.byKey(const Key('calendar-side-by-side-layout')),
    );
    var paneRect = tester.getRect(
      find.byKey(const Key('calendar-event-details-pane')),
    );
    final windowRect = tester.getRect(
      find.byKey(const Key('calendar-event-details-window')),
    );
    expect(paneRect.top, layoutRect.top);
    expect(paneRect.bottom, layoutRect.bottom);
    expect(windowRect.top, greaterThan(paneRect.top + 8));
    expect(windowRect.bottom, lessThan(paneRect.bottom - 8));
    expect(windowRect.left, greaterThan(paneRect.left + 8));
    expect(windowRect.right, lessThan(paneRect.right - 8));

    await tester.tap(find.byKey(const Key('event-details-schedule-card')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('calendar-event-details-pane')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Edit event'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('desktop-item-editor-dialog')), findsOneWidget);
    expect(tester.getSize(find.byType(ItemEditorSheet)).width, 680);
    Navigator.of(tester.element(find.byType(ItemEditorSheet))).pop();
    await tester.pumpAndSettle();

    expect(find.byTooltip('Close event details'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('selected-day-agenda')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agenda-event-desktop-event')));
    await tester.pumpAndSettle();
    paneRect = tester.getRect(
      find.byKey(const Key('calendar-event-details-pane')),
    );
    await tester.tapAt(Offset(paneRect.center.dx, paneRect.bottom - 4));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('selected-day-agenda')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agenda-event-desktop-event')));
    await tester.pumpAndSettle();
    paneRect = tester.getRect(
      find.byKey(const Key('calendar-event-details-pane')),
    );
    await tester.tapAt(Offset(paneRect.center.dx, paneRect.top + 4));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('selected-day-agenda')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('event details remain structured from narrow to wide layouts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final event = Event(
      id: 'responsive-details',
      title: 'A long planning session title that still needs clear hierarchy',
      description:
          'Bring the quarterly notes and review each open decision before the meeting.',
      startTime: DateTime(2026, 9, 4, 9, 30),
      endTime: DateTime(2026, 9, 5, 10, 45),
      tags: const ['Planning', 'Quarterly review', 'Long tag for wrapping'],
      reminder: EventReminder.thirtyMinutesBefore,
      recurrence: EventRecurrence.monthly,
    );

    await tester.pumpWidget(
      Provider<EventRepository>.value(
        value: FakeEventRepository(events: [event]),
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.cyberpunkMega),
          home: Scaffold(
            body: SingleChildScrollView(child: EventDetailsPanel(event: event)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('event-details-title')), findsOneWidget);
    expect(
      find.byKey(const Key('event-details-schedule-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('event-details-description-card')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('event-details-tags')), findsOneWidget);
    expect(find.text('30 minutes before'), findsOneWidget);
    expect(find.text('Repeats monthly'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('event-details-content'))).width,
      640,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirms an event deletion before deleting it', (tester) async {
    final event = Event(
      id: 'event-to-delete',
      title: 'Desktop planning',
      startTime: DateTime(2026, 9, 1, 13),
      endTime: DateTime(2026, 9, 1, 14),
    );
    final repository = FakeEventRepository(events: [event]);
    var deletedCallbackCount = 0;

    await tester.pumpWidget(
      Provider<EventRepository>.value(
        value: repository,
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: Scaffold(
            body: EventDetailsPanel(
              event: event,
              onDeleted: () => deletedCallbackCount++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Delete event'));
    await tester.pumpAndSettle();

    expect(find.text('Delete event?'), findsOneWidget);
    expect(
      find.text('Delete “Desktop planning”? This action cannot be undone.'),
      findsOneWidget,
    );
    expect(repository.deletedEvent, isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.deletedEvent, isNull);
    expect(deletedCallbackCount, 0);

    await tester.tap(find.byTooltip('Delete event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(repository.deletedEvent, same(event));
    expect(deletedCallbackCount, 1);
    expect(find.text('Event deleted'), findsOneWidget);
  });

  testWidgets('shows event failures instead of an empty agenda', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<EventRepository>.value(
            value: FakeEventRepository(
              state: DataFailure(StateError('Firestore unavailable')),
            ),
          ),
          Provider<CalendarReadSource>(
            create:
                (context) => CompositeCalendarReadSource(
                  nativeEventRepository: context.read<EventRepository>(),
                ),
          ),
          ChangeNotifierProvider(create: (_) => SelectedDay()),
        ],
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: const CalendarPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load events'), findsOneWidget);
    expect(find.text('No events for this day'), findsNothing);
  });

  testWidgets('external calendar events open without mutation actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    const google = CalendarEventSource('google', displayName: 'Google');
    final event = CalendarDisplayEvent(
      identity: const CalendarEventIdentity(
        source: google,
        sourceScopedId: 'google-event',
      ),
      title: 'Google planning',
      description: 'Read-only external event',
      startTime: DateTime(now.year, now.month, now.day, 14),
      endTime: DateTime(now.year, now.month, now.day, 15),
      isAllDay: false,
      calendarName: 'Work',
      capabilities: CalendarEventCapabilities.readOnly,
    );
    final snapshot = CalendarReadSnapshot(
      events: [event],
      sources: {
        CalendarEventSource.nexecute: CalendarSourceSnapshot(
          source: CalendarEventSource.nexecute,
          events: const [],
          loadState: CalendarSourceLoadState.failed,
          failure: CalendarSourceFailure(StateError('Firestore unavailable')),
        ),
        google: CalendarSourceSnapshot(
          source: google,
          events: [event],
          loadState: CalendarSourceLoadState.ready,
        ),
      },
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<EventRepository>.value(value: FakeEventRepository()),
          Provider<CalendarReadSource>.value(
            value: _FixedCalendarReadSource(snapshot),
          ),
          ChangeNotifierProvider(create: (_) => SelectedDay()),
        ],
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: const CalendarPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('agenda-event-accent-google:google-event')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('month-event-accent-google:google-event')),
      findsOneWidget,
    );
    final markerSemantics = tester.getSemantics(
      find.byKey(const ValueKey('month-event-accent-google:google-event')),
    );
    expect(markerSemantics.label, contains('Work'));
    expect(markerSemantics.label, contains('Read-only'));
    expect(
      markerSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    await tester.tap(
      find.byKey(const ValueKey('agenda-event-google:google-event')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('event-details-title')), findsOneWidget);
    expect(find.text('Read-only external event'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Read-only'), findsOneWidget);
    expect(find.byKey(const Key('event-details-edit-action')), findsNothing);
    expect(find.byKey(const Key('event-details-delete-action')), findsNothing);
  });

  testWidgets('external details safely open a validated HTTPS event URL', (
    tester,
  ) async {
    const google = CalendarEventSource(
      'google',
      displayName: 'Google Calendar',
    );
    final uri = Uri.parse('https://calendar.google.com/event?eid=safe');
    final event = CalendarDisplayEvent(
      identity: const CalendarEventIdentity(
        source: google,
        sourceScopedId: 'safe-event',
      ),
      title: 'Planning',
      startTime: DateTime(2026, 10, 1, 9),
      endTime: DateTime(2026, 10, 1, 10),
      isAllDay: false,
      calendarName: 'Work',
      calendarColorValue: 0xff4285f4,
      sourceTimeZone: 'Europe/Helsinki',
      externalUrl: uri,
      isStale: true,
      capabilities: const CalendarEventCapabilities(
        canEdit: false,
        canDelete: false,
        canOpenExternally: true,
      ),
    );
    Uri? opened;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemes.forPreset(AppThemePreset.midnight),
        home: Scaffold(
          body: SingleChildScrollView(
            child: CalendarEventDetailsPanel(
              event: event,
              onOpenExternalUrl: (uri) async {
                opened = uri;
                return true;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Google Calendar'), findsOneWidget);
    expect(find.text('Open in Google Calendar'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Read-only'), findsOneWidget);
    expect(
      find.text('Saved copy; refresh for the latest version'),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const Key('event-details-open-external-action')),
    );
    await tester.tap(
      find.byKey(const Key('event-details-open-external-action')),
    );
    await tester.pump();

    expect(opened, uri);
    expect(find.byKey(const Key('event-details-edit-action')), findsNothing);
    expect(find.byKey(const Key('event-details-delete-action')), findsNothing);

    final unsafeEvent = CalendarDisplayEvent(
      identity: const CalendarEventIdentity(
        source: google,
        sourceScopedId: 'unsafe-event',
      ),
      title: 'Unsafe link',
      startTime: DateTime(2026, 10, 1, 9),
      endTime: DateTime(2026, 10, 1, 10),
      isAllDay: false,
      calendarName: 'Work',
      externalUrl: Uri.parse('http://calendar.google.com/private'),
      capabilities: const CalendarEventCapabilities(
        canEdit: false,
        canDelete: false,
        canOpenExternally: true,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CalendarEventDetailsPanel(event: unsafeEvent)),
      ),
    );

    expect(
      find.byKey(const Key('event-details-open-external-action')),
      findsNothing,
    );
  });

  testWidgets('Google refresh failure keeps native Calendar usable', (
    tester,
  ) async {
    final now = DateTime.now();
    final googleEvent = CalendarDisplayEvent(
      identity: const CalendarEventIdentity(
        source: GoogleCalendarSource.google,
        sourceScopedId: 'stale-google-event',
      ),
      title: 'Saved Google event',
      startTime: DateTime(now.year, now.month, now.day, 14),
      endTime: DateTime(now.year, now.month, now.day, 15),
      isAllDay: false,
      calendarName: 'Work',
      isStale: true,
      capabilities: CalendarEventCapabilities.readOnly,
    );
    final snapshot = CalendarReadSnapshot(
      events: [googleEvent],
      sources: {
        CalendarEventSource.nexecute: CalendarSourceSnapshot(
          source: CalendarEventSource.nexecute,
          events: const [],
          loadState: CalendarSourceLoadState.empty,
        ),
        GoogleCalendarSource.google: CalendarSourceSnapshot(
          source: GoogleCalendarSource.google,
          events: [googleEvent],
          loadState: CalendarSourceLoadState.failed,
          failure: const CalendarSourceFailure(
            GoogleCalendarSourceException(
              GoogleCalendarSourceFailureKind.rateLimited,
            ),
          ),
        ),
      },
    );
    final source = _RecordingCalendarReadSource(snapshot);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CalendarReadSource>.value(value: source),
          ChangeNotifierProvider(create: (_) => SelectedDay()),
        ],
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: const CalendarPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved Google event'), findsWidgets);
    expect(find.textContaining('temporarily rate limited'), findsOneWidget);
    await tester.tap(find.byKey(const Key('google-calendar-view-refresh')));
    await tester.pump();

    expect(source.refreshCount, 1);
    expect(find.text('Saved Google event'), findsWidgets);

    final offlineSource = _RecordingCalendarReadSource(
      CalendarReadSnapshot(
        events: [googleEvent],
        sources: {
          CalendarEventSource.nexecute: CalendarSourceSnapshot(
            source: CalendarEventSource.nexecute,
            events: const [],
            loadState: CalendarSourceLoadState.empty,
          ),
          GoogleCalendarSource.google: CalendarSourceSnapshot(
            source: GoogleCalendarSource.google,
            events: [googleEvent],
            loadState: CalendarSourceLoadState.failed,
            failure: const CalendarSourceFailure(
              GoogleCalendarSourceException(
                GoogleCalendarSourceFailureKind.network,
              ),
            ),
          ),
        },
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CalendarReadSource>.value(value: offlineSource),
          ChangeNotifierProvider(create: (_) => SelectedDay()),
        ],
        child: MaterialApp(
          theme: AppThemes.forPreset(AppThemePreset.midnight),
          home: const CalendarPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Google Calendar is offline. Saved events remain visible.'),
      findsOneWidget,
    );
    expect(find.text('Saved Google event'), findsWidgets);
  });
}

final class _FixedCalendarReadSource implements CalendarReadSource {
  const _FixedCalendarReadSource(this.snapshot);

  final CalendarReadSnapshot snapshot;

  @override
  Future<void> refresh(CalendarQueryRange range) async {}

  @override
  Stream<CalendarReadSnapshot> watchEvents(CalendarQueryRange range) =>
      Stream.value(snapshot);
}

final class _RecordingCalendarReadSource implements CalendarReadSource {
  _RecordingCalendarReadSource(this.snapshot);

  final CalendarReadSnapshot snapshot;
  int refreshCount = 0;

  @override
  Future<void> refresh(CalendarQueryRange range) async {
    refreshCount += 1;
  }

  @override
  Stream<CalendarReadSnapshot> watchEvents(CalendarQueryRange range) =>
      Stream.value(snapshot);
}
