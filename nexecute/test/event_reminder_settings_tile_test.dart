import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/home/widgets/event_reminder_settings_tile.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/services/event_reminder_scheduler.dart';

void main() {
  testWidgets('shows device access and can enable event notifications', (
    tester,
  ) async {
    final scheduler = _PermissionScheduler();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EventReminderSettingsTile(scheduler: scheduler)),
      ),
    );
    await tester.pump();

    expect(
      find.text('Notification or exact-alarm access is off on this device.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('enable-event-reminders-button')));
    await tester.pump();

    expect(scheduler.requestCount, 1);
    expect(
      find.text(
        'Allowed on this device. Synced events schedule local reminders here.',
      ),
      findsOneWidget,
    );
  });
}

class _PermissionScheduler implements EventReminderScheduler {
  var status = EventReminderPermissionStatus.denied;
  var requestCount = 0;

  @override
  Future<EventReminderPermissionStatus> checkPermissionStatus() async => status;

  @override
  Future<EventReminderPermissionStatus> requestPermission() async {
    requestCount += 1;
    return status = EventReminderPermissionStatus.authorized;
  }

  @override
  Future<EventReminderScheduleStatus> schedule(Event event) async {
    return EventReminderScheduleStatus.scheduled;
  }

  @override
  Future<void> cancel(String eventId) async {}
}
