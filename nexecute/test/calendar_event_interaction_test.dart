import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/calendar/bottomsheets/event_details.dart';
import 'package:nexecute/home/bottomsheets/item_editor_sheet.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_reminder.dart';
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
    expect(
      tester.getSize(find.byType(EventDetailsBottomSheet)).height,
      greaterThanOrEqualTo(1200 * 0.45),
    );

    await tester.tap(find.byTooltip('Edit event'));
    await tester.pumpAndSettle();

    expect(find.byType(ItemEditorSheet), findsOneWidget);
    expect(find.text('No reminder'), findsOneWidget);

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
