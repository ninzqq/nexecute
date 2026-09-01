import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_recurrence.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/services/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const timeZoneChannel = MethodChannel('flutter_timezone');

  late List<MethodCall> calls;
  late bool initializeResult;
  late bool? permissionRequestResult;
  late Map<String, bool> permissionOptions;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    MacOSFlutterLocalNotificationsPlugin.registerWith();
    calls = [];
    initializeResult = true;
    permissionRequestResult = true;
    permissionOptions = _permissionOptions(isEnabled: true);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'initialize' => initializeResult,
            'checkPermissions' => permissionOptions,
            'requestPermissions' => permissionRequestResult,
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

  test(
    'initializes macOS notifications without requesting permission',
    () async {
      await MacOSEventReminderScheduler.initialize();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'initialize');
      final arguments = calls.single.arguments! as Map<Object?, Object?>;
      expect(arguments['requestAlertPermission'], isFalse);
      expect(arguments['requestSoundPermission'], isFalse);
      expect(arguments['requestBadgePermission'], isFalse);
      expect(arguments['requestProvisionalPermission'], isFalse);
      expect(arguments['requestCriticalPermission'], isFalse);
      expect(arguments['requestProvidesAppNotificationSettings'], isFalse);
      expect(arguments['defaultPresentAlert'], isTrue);
      expect(arguments['defaultPresentSound'], isTrue);
      expect(arguments['defaultPresentBadge'], isFalse);
      expect(arguments['defaultPresentBanner'], isTrue);
      expect(arguments['defaultPresentList'], isTrue);
      expect(
        calls.map((call) => call.method),
        isNot(contains('requestPermissions')),
      );
    },
  );

  test(
    'treats unsuccessful initialization as a construction failure',
    () async {
      initializeResult = false;

      await expectLater(
        MacOSEventReminderScheduler.initialize(),
        throwsStateError,
      );
    },
  );

  test('checks current permission without prompting', () async {
    permissionOptions = _permissionOptions(isEnabled: false);
    final scheduler = await MacOSEventReminderScheduler.initialize();
    calls.clear();

    final status = await scheduler.checkPermissionStatus();

    expect(status, EventReminderPermissionStatus.denied);
    expect(calls.map((call) => call.method), ['checkPermissions']);
  });

  test('requests alert and sound only after an explicit call', () async {
    final scheduler = await MacOSEventReminderScheduler.initialize();
    calls.clear();

    final status = await scheduler.requestPermission();

    expect(status, EventReminderPermissionStatus.authorized);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'requestPermissions');
    expect(calls.single.arguments, <String, Object?>{
      'sound': true,
      'alert': true,
      'badge': false,
      'provisional': false,
      'critical': false,
      'providesAppNotificationSettings': false,
    });
  });

  test('distinguishes an unavailable permission result from denial', () async {
    permissionRequestResult = null;
    final scheduler = await MacOSEventReminderScheduler.initialize();
    calls.clear();

    final status = await scheduler.requestPermission();

    expect(status, EventReminderPermissionStatus.failed);
  });

  test('scheduling never requests permission implicitly', () async {
    permissionOptions = _permissionOptions(isEnabled: false);
    final scheduler = await MacOSEventReminderScheduler.initialize();
    calls.clear();

    final status = await scheduler.schedule(_futureEvent());

    expect(status, EventReminderScheduleStatus.permissionDenied);
    expect(calls.map((call) => call.method), ['cancel', 'checkPermissions']);
    expect(
      calls.map((call) => call.method),
      isNot(contains('requestPermissions')),
    );
    expect(calls.map((call) => call.method), isNot(contains('zonedSchedule')));
  });

  test(
    'schedules an authorized one-shot reminder with private metadata',
    () async {
      final scheduler = await MacOSEventReminderScheduler.initialize();
      calls.clear();
      final event = _futureEvent(description: 'Bring the documents');

      final status = await scheduler.schedule(event);

      expect(status, EventReminderScheduleStatus.scheduled);
      expect(calls.map((call) => call.method), [
        'cancel',
        'checkPermissions',
        'zonedSchedule',
      ]);
      final scheduledCall = calls.last;
      final arguments = scheduledCall.arguments! as Map<Object?, Object?>;
      expect(arguments['id'], eventReminderNotificationId(event.id));
      expect(arguments['title'], event.title);
      expect(arguments['body'], 'Bring the documents');
      expect(arguments['payload'], event.id);
      expect(arguments['timeZoneName'], 'Europe/Helsinki');
      expect(arguments, isNot(contains('matchDateTimeComponents')));

      final platformSpecifics =
          arguments['platformSpecifics']! as Map<Object?, Object?>;
      expect(platformSpecifics['presentAlert'], isTrue);
      expect(platformSpecifics['presentSound'], isTrue);
      expect(platformSpecifics['presentBadge'], isFalse);
      expect(platformSpecifics['presentBanner'], isTrue);
      expect(platformSpecifics['presentList'], isTrue);
      expect(platformSpecifics['badgeNumber'], isNull);
      expect(platformSpecifics['threadIdentifier'], 'calendar-events');
      expect(
        platformSpecifics['interruptionLevel'],
        InterruptionLevel.active.index,
      );
    },
  );

  test('cancels stale requests when reminders are disabled', () async {
    final scheduler = await MacOSEventReminderScheduler.initialize();
    calls.clear();

    final status = await scheduler.schedule(
      _futureEvent(reminder: EventReminder.none),
    );

    expect(status, EventReminderScheduleStatus.notRequested);
    expect(calls.map((call) => call.method), ['cancel']);
  });

  test('defers recurring reminders to the lifecycle reconciler', () async {
    final scheduler = await MacOSEventReminderScheduler.initialize();
    calls.clear();

    final status = await scheduler.schedule(
      _futureEvent(recurrence: EventRecurrence.monthly),
    );

    expect(status, EventReminderScheduleStatus.unsupported);
    expect(calls.map((call) => call.method), ['cancel']);
  });
}

Event _futureEvent({
  String description = '',
  EventReminder reminder = EventReminder.fifteenMinutesBefore,
  EventRecurrence recurrence = EventRecurrence.none,
}) {
  return Event(
    id: 'macos-event',
    title: 'Passport appointment',
    description: description,
    startTime: DateTime(2099, 9, 1, 9),
    endTime: DateTime(2099, 9, 1, 10),
    reminder: reminder,
    recurrence: recurrence,
  );
}

Map<String, bool> _permissionOptions({required bool isEnabled}) {
  return <String, bool>{
    'isEnabled': isEnabled,
    'isSoundEnabled': isEnabled,
    'isAlertEnabled': isEnabled,
    'isBadgeEnabled': false,
    'isProvisionalEnabled': false,
    'isCriticalEnabled': false,
    'isProvidesAppNotificationSettingsEnabled': false,
  };
}
