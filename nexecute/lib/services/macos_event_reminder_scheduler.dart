import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/services/event_reminder_scheduler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class MacOSEventReminderScheduler implements EventReminderScheduler {
  MacOSEventReminderScheduler._({
    required FlutterLocalNotificationsPlugin notifications,
    required tz.Location location,
  }) : _notifications = notifications,
       _location = location;

  static const _threadIdentifier = 'calendar-events';

  final FlutterLocalNotificationsPlugin _notifications;
  final tz.Location _location;

  static Future<MacOSEventReminderScheduler> initialize() async {
    tz_data.initializeTimeZones();
    final timeZone = await FlutterTimezone.getLocalTimezone();
    final location = tz.getLocation(timeZone.identifier);

    final notifications = FlutterLocalNotificationsPlugin();
    final initialized = await notifications.initialize(
      settings: const InitializationSettings(
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestProvisionalPermission: false,
          requestCriticalPermission: false,
          requestProvidesAppNotificationSettings: false,
          defaultPresentAlert: true,
          defaultPresentSound: true,
          defaultPresentBadge: false,
          defaultPresentBanner: true,
          defaultPresentList: true,
        ),
      ),
    );
    if (initialized != true) {
      throw StateError('macOS event notification initialization failed');
    }

    return MacOSEventReminderScheduler._(
      notifications: notifications,
      location: location,
    );
  }

  @override
  Future<EventReminderPermissionStatus> checkPermissionStatus() async {
    try {
      final macOS = _macOSNotifications;
      if (macOS == null) return EventReminderPermissionStatus.unsupported;

      final options = await macOS.checkPermissions();
      if (options == null) return EventReminderPermissionStatus.failed;
      return options.isEnabled
          ? EventReminderPermissionStatus.authorized
          : EventReminderPermissionStatus.denied;
    } catch (_) {
      return EventReminderPermissionStatus.failed;
    }
  }

  @override
  Future<EventReminderPermissionStatus> requestPermission() async {
    try {
      final macOS = _macOSNotifications;
      if (macOS == null) return EventReminderPermissionStatus.unsupported;

      final allowed = await macOS.requestPermissions(
        alert: true,
        sound: true,
        badge: false,
        provisional: false,
        critical: false,
        providesAppNotificationSettings: false,
      );
      if (allowed == null) return EventReminderPermissionStatus.failed;
      return allowed
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
      if (event.recurrence.repeats) {
        return EventReminderScheduleStatus.unsupported;
      }
      if (!scheduledTime.isAfter(DateTime.now())) {
        return EventReminderScheduleStatus.triggerInPast;
      }

      final permissionStatus = await checkPermissionStatus();
      final unavailableStatus = _scheduleStatusForPermission(permissionStatus);
      if (unavailableStatus != null) return unavailableStatus;

      await _notifications.zonedSchedule(
        id: eventReminderNotificationId(event.id),
        title: event.title,
        body: _notificationBody(event),
        scheduledDate: tz.TZDateTime.from(scheduledTime, _location),
        notificationDetails: const NotificationDetails(
          macOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: false,
            presentBanner: true,
            presentList: true,
            threadIdentifier: _threadIdentifier,
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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

  MacOSFlutterLocalNotificationsPlugin? get _macOSNotifications =>
      _notifications
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();

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
