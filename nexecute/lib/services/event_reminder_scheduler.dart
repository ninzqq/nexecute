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

abstract interface class PendingEventReminderReader {
  Future<Set<String>> pendingEventIds();
}

enum EventReminderNotificationKind { standard, allDayTomorrow, allDayToday }

final class EventReminderNotification {
  const EventReminderNotification({
    required this.kind,
    required this.scheduledTime,
    required this.title,
    required this.body,
  });

  final EventReminderNotificationKind kind;
  final DateTime scheduledTime;
  final String title;
  final String body;
}

List<EventReminderNotification> eventReminderNotifications(Event event) {
  if (event.reminder == EventReminder.none) return const [];

  if (event.isAllDay) {
    final eventDate = DateTime(
      event.startTime.year,
      event.startTime.month,
      event.startTime.day,
    );
    return [
      EventReminderNotification(
        kind: EventReminderNotificationKind.allDayTomorrow,
        scheduledTime: DateTime(
          eventDate.year,
          eventDate.month,
          eventDate.day - 1,
          21,
        ),
        title: eventReminderNotificationTitle(
          event,
          EventReminderNotificationKind.allDayTomorrow,
        ),
        body: eventReminderNotificationBody(
          event,
          EventReminderNotificationKind.allDayTomorrow,
        ),
      ),
      EventReminderNotification(
        kind: EventReminderNotificationKind.allDayToday,
        scheduledTime: DateTime(
          eventDate.year,
          eventDate.month,
          eventDate.day,
          9,
        ),
        title: eventReminderNotificationTitle(
          event,
          EventReminderNotificationKind.allDayToday,
        ),
        body: eventReminderNotificationBody(
          event,
          EventReminderNotificationKind.allDayToday,
        ),
      ),
    ];
  }

  final scheduledTime = event.reminder.scheduledTime(event.startTime)!;
  return [
    EventReminderNotification(
      kind: EventReminderNotificationKind.standard,
      scheduledTime: scheduledTime,
      title: eventReminderNotificationTitle(
        event,
        EventReminderNotificationKind.standard,
      ),
      body: eventReminderNotificationBody(
        event,
        EventReminderNotificationKind.standard,
      ),
    ),
  ];
}

String eventReminderNotificationTitle(
  Event event,
  EventReminderNotificationKind kind,
) =>
    kind == EventReminderNotificationKind.allDayTomorrow
        ? '${event.title} Tomorrow'
        : event.title;

String eventReminderNotificationBody(
  Event event,
  EventReminderNotificationKind kind,
) {
  final description = event.description.trim();
  if (description.isNotEmpty) return description;
  return switch (kind) {
    EventReminderNotificationKind.standard =>
      event.reminder == EventReminder.atStart
          ? 'Starting now'
          : 'Starting soon',
    EventReminderNotificationKind.allDayTomorrow => 'All-day event',
    EventReminderNotificationKind.allDayToday => 'Today',
  };
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

class AndroidEventReminderScheduler
    implements EventReminderScheduler, PendingEventReminderReader {
  AndroidEventReminderScheduler._({
    required FlutterLocalNotificationsPlugin notifications,
    required tz.Location location,
    required DateTime Function() now,
  }) : _notifications = notifications,
       _location = location,
       _now = now;

  static const _channelId = 'calendar_event_reminders';
  static const _channelName = 'Calendar event reminders';
  static const _channelDescription =
      'Reminders scheduled for upcoming calendar events';

  final FlutterLocalNotificationsPlugin _notifications;
  final tz.Location _location;
  final DateTime Function() _now;
  final Map<String, Event> _pendingEvents = {};

  static Future<AndroidEventReminderScheduler> initialize({
    DateTime Function()? now,
  }) async {
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
      now: now ?? DateTime.now,
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
      final status =
          exactAlarmsAllowed
              ? EventReminderPermissionStatus.authorized
              : EventReminderPermissionStatus.denied;
      if (status == EventReminderPermissionStatus.authorized) {
        await _retryPendingEvents();
      }
      return status;
    } catch (_) {
      return EventReminderPermissionStatus.failed;
    }
  }

  Future<EventReminderPermissionStatus> _requestNotificationPermission() async {
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
      return notificationsAllowed
          ? EventReminderPermissionStatus.authorized
          : EventReminderPermissionStatus.denied;
    } catch (_) {
      return EventReminderPermissionStatus.failed;
    }
  }

  @override
  Future<EventReminderScheduleStatus> schedule(Event event) async {
    try {
      await _cancelScheduledNotifications(event.id);

      final reminders = eventReminderNotifications(event);
      if (reminders.isEmpty) {
        _pendingEvents.remove(event.id);
        return EventReminderScheduleStatus.notRequested;
      }
      final now = _now();
      final deliverImmediately =
          !event.recurrence.repeats &&
          !event.isAllDay &&
          event.reminder == EventReminder.atStart &&
          !reminders.single.scheduledTime.isAfter(now) &&
          _isSameLocalMinute(reminders.single.scheduledTime, now);
      final schedulableReminders =
          event.recurrence.repeats
              ? reminders
              : reminders
                  .where((reminder) => reminder.scheduledTime.isAfter(now))
                  .toList(growable: false);
      if (!event.recurrence.repeats &&
          schedulableReminders.isEmpty &&
          !deliverImmediately) {
        _pendingEvents.remove(event.id);
        return EventReminderScheduleStatus.triggerInPast;
      }

      final permissionStatus =
          deliverImmediately
              ? await _requestNotificationPermission()
              : await requestPermission();
      final unavailableStatus = _scheduleStatusForPermission(permissionStatus);
      if (unavailableStatus != null) {
        if (permissionStatus != EventReminderPermissionStatus.unsupported) {
          _pendingEvents[event.id] = event;
        }
        return unavailableStatus;
      }

      _pendingEvents.remove(event.id);
      if (deliverImmediately) {
        final reminder = reminders.single;
        await _notifications.show(
          id: eventReminderNotificationId(event.id),
          title: reminder.title,
          body: reminder.body,
          notificationDetails: _notificationDetails,
          payload: event.id,
        );
      } else {
        for (final reminder in schedulableReminders) {
          await _notifications.zonedSchedule(
            id: eventReminderNotificationId(event.id, reminder.kind),
            title: reminder.title,
            body: reminder.body,
            scheduledDate: tz.TZDateTime.from(
              reminder.scheduledTime,
              _location,
            ),
            notificationDetails: _notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: eventReminderDateTimeComponents(
              event.recurrence,
            ),
            payload: event.id,
          );
        }
      }
      return EventReminderScheduleStatus.scheduled;
    } catch (_) {
      return EventReminderScheduleStatus.failed;
    }
  }

  @override
  Future<void> cancel(String eventId) => _cancelScheduledNotifications(eventId);

  Future<void> _cancelScheduledNotifications(String eventId) async {
    _pendingEvents.remove(eventId);
    await _notifications.cancel(id: eventReminderNotificationId(eventId));
    await _notifications.cancel(
      id: eventReminderNotificationId(
        eventId,
        EventReminderNotificationKind.allDayTomorrow,
      ),
    );
    await _notifications.cancel(
      id: eventReminderNotificationId(
        eventId,
        EventReminderNotificationKind.allDayToday,
      ),
    );
  }

  @override
  Future<Set<String>> pendingEventIds() async {
    final requests = await _notifications.pendingNotificationRequests();
    return requests
        .map((request) => request.payload)
        .whereType<String>()
        .toSet();
  }

  Future<void> _retryPendingEvents() async {
    final pending = _pendingEvents.values.toList(growable: false);
    _pendingEvents.clear();
    for (final event in pending) {
      await schedule(event);
    }
  }

  static const _notificationDetails = NotificationDetails(
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
  );
}

bool _isSameLocalMinute(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day &&
    first.hour == second.hour &&
    first.minute == second.minute;

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

int eventReminderNotificationId(
  String eventId, [
  EventReminderNotificationKind kind = EventReminderNotificationKind.standard,
]) {
  final notificationKey =
      kind == EventReminderNotificationKind.standard
          ? eventId
          : '$eventId:${kind.name}';
  var hash = 0x811c9dc5;
  for (final codeUnit in notificationKey.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
