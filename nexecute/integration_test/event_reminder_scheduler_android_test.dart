import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/services/event_reminder_scheduler.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('schedules and cancels an Android event reminder', (
    tester,
  ) async {
    final scheduler = await AndroidEventReminderScheduler.initialize();
    final event = Event(
      id: 'android-reminder-integration-test',
      title: 'Reminder integration test',
      startTime: DateTime.now().add(const Duration(days: 2)),
      endTime: DateTime.now().add(const Duration(days: 2, hours: 1)),
      reminder: EventReminder.oneHourBefore,
    );
    final notificationId = eventReminderNotificationId(event.id);
    addTearDown(() => scheduler.cancel(event.id));

    final status = await scheduler.schedule(event);

    expect(status, EventReminderScheduleStatus.scheduled);
    final notifications = FlutterLocalNotificationsPlugin();
    final pendingAfterSchedule =
        await notifications.pendingNotificationRequests();
    expect(
      pendingAfterSchedule.any((request) => request.id == notificationId),
      isTrue,
    );

    await scheduler.cancel(event.id);

    final pendingAfterCancel =
        await notifications.pendingNotificationRequests();
    expect(
      pendingAfterCancel.any((request) => request.id == notificationId),
      isFalse,
    );
  });

  testWidgets('delivers an Android event reminder', (tester) async {
    final scheduler = await AndroidEventReminderScheduler.initialize();
    final startTime = DateTime.now().add(const Duration(seconds: 5));
    final event = Event(
      id: 'android-reminder-delivery-test',
      title: 'Delivered reminder',
      startTime: startTime,
      endTime: startTime.add(const Duration(hours: 1)),
      reminder: EventReminder.atStart,
    );
    final notificationId = eventReminderNotificationId(event.id);
    addTearDown(() => scheduler.cancel(event.id));

    expect(
      await scheduler.schedule(event),
      EventReminderScheduleStatus.scheduled,
    );
    await Future<void>.delayed(const Duration(seconds: 8));

    final activeNotifications =
        await FlutterLocalNotificationsPlugin().getActiveNotifications();
    expect(
      activeNotifications.any(
        (notification) => notification.id == notificationId,
      ),
      isTrue,
    );
  });
}
