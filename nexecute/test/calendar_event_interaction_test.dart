import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/calendar/bottomsheets/event_details.dart';
import 'package:nexecute/home/bottomsheets/item_editor_sheet.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/models/event_recurrence.dart';
import 'package:nexecute/models/selected_day.dart';
import 'package:nexecute/models/tag.dart' as models;
import 'package:nexecute/repositories/event_repository.dart';
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
      recurrence: EventRecurrence.yearly,
      recurrenceSeriesStartTime: DateTime(now.year - 1, now.month, now.day, 9),
      recurrenceSeriesEndTime: DateTime(now.year - 1, now.month, now.day, 10),
    );

    final repository = FakeEventRepository(events: [event]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<EventRepository>.value(value: repository),
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
    expect(find.text('Prepare the monthly plan'), findsOneWidget);
    expect(find.text('Repeats yearly'), findsOneWidget);
    expect(
      tester.getSize(find.byType(EventDetailsBottomSheet)).height,
      greaterThanOrEqualTo(1200 * 0.45),
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
    expect(find.text('Details stay beside the calendar'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit event'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(ItemEditorSheet)).width, 640);
    Navigator.of(tester.element(find.byType(ItemEditorSheet))).pop();
    await tester.pumpAndSettle();

    expect(find.byTooltip('Close event details'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('selected-day-agenda')), findsOneWidget);
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
}
