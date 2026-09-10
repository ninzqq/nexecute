import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/services/event_reminder_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AndroidFlutterLocalNotificationsPlugin.registerWith();

  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const timeZoneChannel = MethodChannel('flutter_timezone');

  late List<MethodCall> calls;
  late bool notificationsAllowed;
  late bool exactAlarmsAllowed;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls = [];
    notificationsAllowed = true;
    exactAlarmsAllowed = true;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'initialize' => true,
            'areNotificationsEnabled' => notificationsAllowed,
            'requestNotificationsPermission' => notificationsAllowed,
            'canScheduleExactNotifications' => exactAlarmsAllowed,
            'requestExactAlarmsPermission' => exactAlarmsAllowed,
            _ => null,
          };
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timeZoneChannel, (call) async {
          expect(call.method, 'getLocalTimezone');
          return 'Europe/Helsinki';
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timeZoneChannel, null);
  });

  test('delivers a just-passed at-event-time reminder immediately', () async {
    final now = DateTime(2099, 9, 3, 14, 30, 40);
    final scheduler = await AndroidEventReminderScheduler.initialize(
      now: () => now,
    );
    calls.clear();
    final event = _event(startTime: DateTime(2099, 9, 3, 14, 30, 10));

    final status = await scheduler.schedule(event);

    expect(
      status,
      EventReminderScheduleStatus.scheduled,
      reason: calls.map((call) => call.method).toList().toString(),
    );
    expect(calls.map((call) => call.method), [
      'cancel',
      'cancel',
      'cancel',
      'areNotificationsEnabled',
      'show',
    ]);
    expect(
      calls.map((call) => call.method),
      isNot(contains('canScheduleExactNotifications')),
    );
    final arguments = calls.last.arguments! as Map<Object?, Object?>;
    expect(arguments['id'], eventReminderNotificationId(event.id));
    expect(arguments['title'], event.title);
    expect(arguments['body'], 'Starting now');
    expect(arguments['payload'], event.id);
  });

  test('still schedules a future at-event-time reminder', () async {
    final now = DateTime(2099, 9, 3, 14, 30, 10);
    final scheduler = await AndroidEventReminderScheduler.initialize(
      now: () => now,
    );
    calls.clear();

    final status = await scheduler.schedule(
      _event(startTime: DateTime(2099, 9, 3, 14, 30, 40)),
    );

    expect(
      status,
      EventReminderScheduleStatus.scheduled,
      reason: calls.map((call) => call.method).toList().toString(),
    );
    expect(calls.map((call) => call.method), [
      'cancel',
      'cancel',
      'cancel',
      'areNotificationsEnabled',
      'canScheduleExactNotifications',
      'zonedSchedule',
    ]);
  });

  test('does not deliver an older at-event-time reminder', () async {
    final now = DateTime(2099, 9, 3, 14, 31);
    final scheduler = await AndroidEventReminderScheduler.initialize(
      now: () => now,
    );
    calls.clear();

    final status = await scheduler.schedule(
      _event(startTime: DateTime(2099, 9, 3, 14, 30, 59)),
    );

    expect(status, EventReminderScheduleStatus.triggerInPast);
    expect(calls.map((call) => call.method), ['cancel', 'cancel', 'cancel']);
  });

  test(
    'schedules pending events after exact-alarm access is enabled',
    () async {
      final now = DateTime(2099, 9, 3, 14, 30, 10);
      final scheduler = await AndroidEventReminderScheduler.initialize(
        now: () => now,
      );
      calls.clear();
      exactAlarmsAllowed = false;
      final event = _event(startTime: DateTime(2099, 9, 3, 15));

      expect(
        await scheduler.schedule(event),
        EventReminderScheduleStatus.permissionDenied,
      );
      expect(
        calls.map((call) => call.method),
        contains('requestExactAlarmsPermission'),
      );

      calls.clear();
      exactAlarmsAllowed = true;
      expect(
        await scheduler.requestPermission(),
        EventReminderPermissionStatus.authorized,
      );
      expect(calls.map((call) => call.method), contains('zonedSchedule'));
    },
  );

  test('schedules both all-day reminders with distinct copy and IDs', () async {
    final scheduler = await AndroidEventReminderScheduler.initialize(
      now: () => DateTime(2099, 8, 31, 12),
    );
    calls.clear();
    final event = Event(
      id: 'android-all-day',
      title: 'Launch day',
      startTime: DateTime(2099, 9, 1),
      endTime: DateTime(2099, 9, 2),
      isAllDay: true,
      reminder: EventReminder.atStart,
    );

    final status = await scheduler.schedule(event);

    expect(status, EventReminderScheduleStatus.scheduled);
    final schedules = calls.where((call) => call.method == 'zonedSchedule');
    expect(schedules, hasLength(2));
    final arguments =
        schedules
            .map((call) => call.arguments! as Map<Object?, Object?>)
            .toList();
    expect(arguments.map((value) => value['title']), [
      'Launch day Tomorrow',
      'Launch day',
    ]);
    expect(arguments.map((value) => value['body']), ['All-day event', 'Today']);
    expect(arguments.map((value) => value['id']).toSet(), hasLength(2));
    expect(arguments.every((value) => value['payload'] == event.id), isTrue);
  });
}

Event _event({required DateTime startTime}) {
  return Event(
    id: 'android-at-event-time',
    title: 'Stand-up',
    startTime: startTime,
    endTime: startTime.add(const Duration(hours: 1)),
    reminder: EventReminder.atStart,
  );
}
