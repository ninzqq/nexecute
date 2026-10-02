import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/domain/calendar/calendar_display_event.dart';
import 'package:nexecute/domain/calendar/calendar_query_range.dart';
import 'package:nexecute/models/selected_day.dart';
import 'package:nexecute/repositories/calendar_read_source.dart';
import 'package:nexecute/repositories/google_calendar_source.dart';
import 'package:nexecute/themes.dart';
import 'package:nexecute/ui/calendar/calendar.dart';
import 'package:provider/provider.dart';

void main() {
  const layouts = <String, Size>{
    'compact': Size(390, 844),
    'expanded': Size(1200, 900),
  };
  final now = DateTime(2026, 10, 2, 12);
  final event = CalendarDisplayEvent(
    identity: const CalendarEventIdentity(
      source: GoogleCalendarSource.google,
      sourceScopedId: 'theme-layout-event',
    ),
    title: 'Google design review',
    description: 'Review the calendar widget across themes and layouts.',
    startTime: DateTime(2026, 10, 2, 14),
    endTime: DateTime(2026, 10, 2, 15),
    isAllDay: false,
    calendarName: 'Product',
    calendarColorValue: 0xff4285f4,
    sourceTimeZone: 'Europe/Helsinki',
    externalUrl: Uri.parse(
      'https://calendar.google.com/calendar/event?eid=theme-layout-event',
    ),
    capabilities: const CalendarEventCapabilities(
      canEdit: false,
      canDelete: false,
      canOpenExternally: true,
    ),
  );
  final snapshot = CalendarReadSnapshot(
    events: [event],
    sources: {
      CalendarEventSource.nexecute: CalendarSourceSnapshot(
        source: CalendarEventSource.nexecute,
        events: const [],
        loadState: CalendarSourceLoadState.empty,
      ),
      GoogleCalendarSource.google: CalendarSourceSnapshot(
        source: GoogleCalendarSource.google,
        events: [event],
        loadState: CalendarSourceLoadState.ready,
      ),
    },
  );

  for (final preset in AppThemePreset.values) {
    for (final layout in layouts.entries) {
      testWidgets(
        'Google Calendar event renders in ${preset.name} ${layout.key} layout',
        (tester) async {
          tester.view.physicalSize = layout.value;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                Provider<CalendarReadSource>.value(
                  value: _FixedCalendarReadSource(snapshot),
                ),
                ChangeNotifierProvider(create: (_) => SelectedDay()),
              ],
              child: MaterialApp(
                theme: AppThemes.forPreset(preset),
                home: Scaffold(body: CalendarPage(now: () => now)),
              ),
            ),
          );
          await tester.pumpAndSettle();

          const eventIdentity = 'google:theme-layout-event';
          final agendaEvent = find.byKey(
            const ValueKey('agenda-event-$eventIdentity'),
          );
          expect(
            find.byKey(const ValueKey('agenda-event-accent-$eventIdentity')),
            findsOneWidget,
          );
          final accent = tester.widget<Container>(
            find.byKey(const ValueKey('agenda-event-accent-$eventIdentity')),
          );
          expect(
            (accent.decoration! as BoxDecoration).color,
            const Color(0xff4285f4),
          );
          expect(find.text('Google design review'), findsWidgets);
          expect(tester.takeException(), isNull);

          await tester.tap(agendaEvent);
          await tester.pumpAndSettle();

          if (layout.key == 'expanded') {
            expect(
              find.byKey(const Key('calendar-event-details-pane')),
              findsOneWidget,
            );
          }
          expect(
            find.byKey(const Key('event-details-source-card')),
            findsOneWidget,
          );
          expect(find.text('Google Calendar'), findsOneWidget);
          expect(find.text('Product'), findsOneWidget);
          expect(find.text('Read-only'), findsOneWidget);
          expect(find.text('Europe/Helsinki'), findsOneWidget);
          expect(
            find.byKey(const Key('event-details-open-external-action')),
            findsOneWidget,
          );
          expect(find.text('Open in Google Calendar'), findsOneWidget);
          expect(
            find.byKey(const Key('event-details-edit-action')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('event-details-delete-action')),
            findsNothing,
          );
          expect(find.text('Edit event'), findsNothing);
          expect(find.text('Delete event'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
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
