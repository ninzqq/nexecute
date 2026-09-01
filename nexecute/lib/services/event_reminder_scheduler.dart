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

enum EventReminderPermissionStatus { authorized, denied, unsupported, failed }

abstract interface class EventReminderScheduler {
  Future<EventReminderPermissionStatus> checkPermissionStatus();

  Future<EventReminderPermissionStatus> requestPermission();

  Future<EventReminderScheduleStatus> schedule(Event event);

  Future<void> cancel(String eventId);
}

class NoopEventReminderScheduler implements EventReminderScheduler {
  const NoopEventReminderScheduler();

  @override
  Future<EventReminderPermissionStatus> checkPermissionStatus() async {
    return EventReminderPermissionStatus.unsupported;
  }

  @override
  Future<EventReminderPermissionStatus> requestPermission() async {
    return EventReminderPermissionStatus.unsupported;
  }

  @override
  Future<EventReminderScheduleStatus> schedule(Event event) async {
    return event.reminder == EventReminder.none
        ? EventReminderScheduleStatus.notRequested
        : EventReminderScheduleStatus.unsupported;
  }

  @override
  Future<void> cancel(String eventId) async {}
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
  Future<EventReminderPermissionStatus> checkPermissionStatus() async {
    try {
      final android =
          _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (android == null) return EventReminderPermissionStatus.unsupported;

      final notificationsAllowed =
          await android.areNotificationsEnabled() == true;
      final exactAlarmsAllowed =
          await android.canScheduleExactNotifications() == true;
      return notificationsAllowed && exactAlarmsAllowed
          ? EventReminderPermissionStatus.authorized
          : EventReminderPermissionStatus.denied;
    } catch (_) {
      return EventReminderPermissionStatus.failed;
    }
  }

  @override
  Future<EventReminderPermissionStatus> requestPermission() async {
    try {
      final android =
          _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (android == null) return EventReminderPermissionStatus.unsupported;

      final notificationsAllowed =
          await android.areNotificationsEnabled() == true ||
          await android.requestNotificationsPermission() == true;
      if (!notificationsAllowed) return EventReminderPermissionStatus.denied;

      final exactAlarmsAllowed =
          await android.canScheduleExactNotifications() == true ||
          await android.requestExactAlarmsPermission() == true;
      return exactAlarmsAllowed
          ? EventReminderPermissionStatus.authorized
          : EventReminderPermissionStatus.denied;
    } catch (_) {
      return EventReminderPermissionStatus.failed;
    }
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

      final permissionStatus = await requestPermission();
      final unavailableStatus = _scheduleStatusForPermission(permissionStatus);
      if (unavailableStatus != null) return unavailableStatus;

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

EventReminderScheduleStatus? _scheduleStatusForPermission(
  EventReminderPermissionStatus status,
) => switch (status) {
  EventReminderPermissionStatus.authorized => null,
  EventReminderPermissionStatus.denied =>
    EventReminderScheduleStatus.permissionDenied,
  EventReminderPermissionStatus.unsupported =>
    EventReminderScheduleStatus.unsupported,
  EventReminderPermissionStatus.failed => EventReminderScheduleStatus.failed,
};

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
