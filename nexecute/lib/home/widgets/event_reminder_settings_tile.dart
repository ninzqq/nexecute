import 'package:flutter/material.dart';
import 'package:nexecute/services/event_reminder_scheduler.dart';

class EventReminderSettingsTile extends StatefulWidget {
  const EventReminderSettingsTile({super.key, required this.scheduler});

  final EventReminderScheduler? scheduler;

  @override
  State<EventReminderSettingsTile> createState() =>
      _EventReminderSettingsTileState();
}

class _EventReminderSettingsTileState extends State<EventReminderSettingsTile> {
  EventReminderPermissionStatus? _status;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void didUpdateWidget(EventReminderSettingsTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.scheduler, widget.scheduler)) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    final scheduler = widget.scheduler;
    if (scheduler == null) {
      if (mounted) {
        setState(() => _status = EventReminderPermissionStatus.unsupported);
      }
      return;
    }
    final status = await scheduler.checkPermissionStatus();
    if (mounted) setState(() => _status = status);
  }

  Future<void> _requestPermission() async {
    final scheduler = widget.scheduler;
    if (scheduler == null || _requesting) return;
    setState(() => _requesting = true);
    final status = await scheduler.requestPermission();
    if (!mounted) return;
    setState(() {
      _status = status;
      _requesting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return ListTile(
      key: const Key('event-reminder-permission-tile'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        status == EventReminderPermissionStatus.authorized
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
      ),
      title: const Text('Event notifications'),
      subtitle: Text(_description(status)),
      trailing: switch (status) {
        EventReminderPermissionStatus.denied ||
        EventReminderPermissionStatus.failed => FilledButton.tonal(
          key: const Key('enable-event-reminders-button'),
          onPressed: _requesting ? null : _requestPermission,
          child:
              _requesting
                  ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Text(
                    status == EventReminderPermissionStatus.denied
                        ? 'Enable'
                        : 'Retry',
                  ),
        ),
        _ => null,
      },
    );
  }
}

String _description(EventReminderPermissionStatus? status) => switch (status) {
  null => 'Checking access on this device…',
  EventReminderPermissionStatus.authorized =>
    'Allowed on this device. Synced events schedule local reminders here.',
  EventReminderPermissionStatus.denied =>
    'Notification or exact-alarm access is off on this device.',
  EventReminderPermissionStatus.unsupported =>
    'Event notifications are unavailable on this device.',
  EventReminderPermissionStatus.failed =>
    'Nexecute could not check notification access on this device.',
};
