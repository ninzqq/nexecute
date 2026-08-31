import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/models/event_recurrence.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

enum EventReminderScheduleStatus {
  scheduled,
  notRequested,
  triggerInPast,
  permissionDenied,
  unsupported,
  failed,
}

abstract interface class EventReminderScheduler {
  Future<EventReminderScheduleStatus> schedule(Event event);

  Future<void> cancel(String eventId);
}

class NoopEventReminderScheduler implements EventReminderScheduler {
  const NoopEventReminderScheduler();

  @override
  Future<EventReminderScheduleStatus> schedule(Event event) async {
    return event.reminder == EventReminder.none
        ? EventReminderScheduleStatus.notRequested
        : EventReminderScheduleStatus.unsupported;
  }

  @override
  Future<void> cancel(String eventId) async {}
}

Future<EventReminderScheduler> createDefaultEventReminderScheduler() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return const NoopEventReminderScheduler();
  }

  try {
    return await AndroidEventReminderScheduler.initialize();
  } catch (_) {
    return const NoopEventReminderScheduler();
  }
}

class AndroidEventReminderScheduler implements EventReminderScheduler {
  AndroidEventReminderScheduler._({
    required FlutterLocalNotificationsPlugin notifications,
    required tz.Location location,
  }) : _notifications = notifications,
       _location = location;

  static const _channelId = 'calendar_event_reminders';
  static const _channelName = 'Calendar event reminders';
  static const _channelDescription =
      'Reminders scheduled for upcoming calendar events';

  final FlutterLocalNotificationsPlugin _notifications;
  final tz.Location _location;

  static Future<AndroidEventReminderScheduler> initialize() async {
    tz_data.initializeTimeZones();
    final timeZone = await FlutterTimezone.getLocalTimezone();
    final location = tz.getLocation(timeZone.identifier);
    tz.setLocalLocation(location);

    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );

    return AndroidEventReminderScheduler._(
      notifications: notifications,
      location: location,
    );
  }

  @override
  Future<EventReminderScheduleStatus> schedule(Event event) async {
    try {
      await cancel(event.id);

      final scheduledTime = event.reminder.scheduledTime(event.startTime);
      if (scheduledTime == null) {
        return EventReminderScheduleStatus.notRequested;
      }
      if (!event.recurrence.repeats && !scheduledTime.isAfter(DateTime.now())) {
        return EventReminderScheduleStatus.triggerInPast;
      }

      final android =
          _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (android == null) return EventReminderScheduleStatus.unsupported;

      final notificationsAllowed =
          await android.areNotificationsEnabled() == true ||
          await android.requestNotificationsPermission() == true;
      if (!notificationsAllowed) {
        return EventReminderScheduleStatus.permissionDenied;
      }

      final exactAlarmsAllowed =
          await android.canScheduleExactNotifications() == true ||
          await android.requestExactAlarmsPermission() == true;
      if (!exactAlarmsAllowed) {
        return EventReminderScheduleStatus.permissionDenied;
      }

      await _notifications.zonedSchedule(
        id: eventReminderNotificationId(event.id),
        title: event.title,
        body: _notificationBody(event),
        scheduledDate: tz.TZDateTime.from(scheduledTime, _location),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            icon: 'ic_notification',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.event,
            visibility: NotificationVisibility.private,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: eventReminderDateTimeComponents(
          event.recurrence,
        ),
        payload: event.id,
      );
      return EventReminderScheduleStatus.scheduled;
    } catch (_) {
      return EventReminderScheduleStatus.failed;
    }
  }

  @override
  Future<void> cancel(String eventId) {
    return _notifications.cancel(id: eventReminderNotificationId(eventId));
  }

  String _notificationBody(Event event) {
    if (event.description.trim().isNotEmpty) return event.description.trim();
    return event.reminder == EventReminder.atStart
        ? 'Starting now'
        : 'Starting soon';
  }
}

DateTimeComponents? eventReminderDateTimeComponents(
  EventRecurrence recurrence,
) => switch (recurrence) {
  EventRecurrence.none => null,
  EventRecurrence.daily => DateTimeComponents.time,
  EventRecurrence.weekly => DateTimeComponents.dayOfWeekAndTime,
  EventRecurrence.monthly => DateTimeComponents.dayOfMonthAndTime,
  EventRecurrence.yearly => DateTimeComponents.dateAndTime,
};

int eventReminderNotificationId(String eventId) {
  var hash = 0x811c9dc5;
  for (final codeUnit in eventId.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
