import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/calendar/bottomsheets/event_details.dart';
import 'package:nexecute/home/bottomsheets/item_editor_sheet.dart';
import 'package:nexecute/models/event.dart';
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

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<EventRepository>.value(
            value: FakeEventRepository(events: [event]),
          ),
          Provider<models.Tags>.value(value: models.Tags()),
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
  });
}
