import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/event_reminder.dart';
import 'package:nexecute/services/services.dart';
import 'package:nexecute/themes.dart';

void main() {
  test('resolves supported runtime platforms in one place', () {
    expect(
      resolveAppRuntimePlatform(
        isWeb: false,
        targetPlatform: TargetPlatform.android,
      ),
      AppRuntimePlatform.android,
    );
    expect(
      resolveAppRuntimePlatform(
        isWeb: false,
        targetPlatform: TargetPlatform.macOS,
      ),
      AppRuntimePlatform.macOS,
    );
    expect(
      resolveAppRuntimePlatform(
        isWeb: true,
        targetPlatform: TargetPlatform.android,
      ),
      AppRuntimePlatform.web,
    );
    expect(
      resolveAppRuntimePlatform(
        isWeb: false,
        targetPlatform: TargetPlatform.linux,
      ),
      AppRuntimePlatform.unsupported,
    );
  });

  test(
    'Android receives its reminder, widget, and credential services',
    () async {
      final reminder = _RecordingReminderScheduler();
      final widget = _RecordingEventWidgetUpdater();
      final credentials = _MemoryCredentialStore();

      final services = await createAppPlatformServices(
        AppRuntimePlatform.android,
        androidReminderInitializer: () async => reminder,
        androidWidgetFactory: () => widget,
        androidCredentialStoreFactory: () => credentials,
      );

      expect(services.platform, AppRuntimePlatform.android);
      expect(services.reminderScheduler, same(reminder));
      expect(services.eventWidgetUpdater, same(widget));
      expect(services.aiCredentialStore, same(credentials));
    },
  );

  test('Android reminder initialization retains its safe fallback', () async {
    final widget = _RecordingEventWidgetUpdater();
    final credentials = _MemoryCredentialStore();

    final services = await createAppPlatformServices(
      AppRuntimePlatform.android,
      androidReminderInitializer:
          () => Future.error(StateError('notifications unavailable')),
      androidWidgetFactory: () => widget,
      androidCredentialStoreFactory: () => credentials,
    );

    expect(services.reminderScheduler, isA<NoopEventReminderScheduler>());
    expect(services.eventWidgetUpdater, same(widget));
    expect(services.aiCredentialStore, same(credentials));
  });

  test('macOS receives no-op native services and secure credentials', () async {
    var androidFactoryCalled = false;
    final credentials = _MemoryCredentialStore();

    final services = await createAppPlatformServices(
      AppRuntimePlatform.macOS,
      androidReminderInitializer: () async {
        androidFactoryCalled = true;
        return _RecordingReminderScheduler();
      },
      androidWidgetFactory: () {
        androidFactoryCalled = true;
        return _RecordingEventWidgetUpdater();
      },
      androidCredentialStoreFactory: () {
        androidFactoryCalled = true;
        return _MemoryCredentialStore();
      },
      macOSCredentialStoreFactory: () => credentials,
    );

    expect(androidFactoryCalled, isFalse);
    expect(services.platform, AppRuntimePlatform.macOS);
    expect(services.reminderScheduler, isA<NoopEventReminderScheduler>());
    expect(services.eventWidgetUpdater, isA<NoopEventWidgetUpdater>());
    expect(services.aiCredentialStore, same(credentials));

    final reminderStatus = await services.reminderScheduler.schedule(
      Event(
        id: 'macos-reminder',
        title: 'Unsupported reminder',
        startTime: DateTime(2026, 9, 1, 10),
        endTime: DateTime(2026, 9, 1, 11),
        reminder: EventReminder.atStart,
      ),
    );
    expect(reminderStatus, EventReminderScheduleStatus.unsupported);

    await services.eventWidgetUpdater.updateCurrentWeek(
      const [],
      theme: AppThemePreset.neutral,
    );
    await services.eventWidgetUpdater.updateStatus('ignored');
    await services.eventWidgetUpdater.updateTheme(AppThemePreset.forest);
  });

  test(
    'web and unsupported platforms use explicit unavailable bundles',
    () async {
      final web = await createAppPlatformServices(AppRuntimePlatform.web);
      final unsupported = await createAppPlatformServices(
        AppRuntimePlatform.unsupported,
      );

      expect(web.platform, AppRuntimePlatform.web);
      expect(unsupported.platform, AppRuntimePlatform.unsupported);
      expect(web.eventWidgetUpdater, isA<NoopEventWidgetUpdater>());
      expect(
        unsupported.aiCredentialStore,
        isA<UnavailableAiCredentialStore>(),
      );
    },
  );
}

class _RecordingReminderScheduler implements EventReminderScheduler {
  @override
  Future<void> cancel(String eventId) async {}

  @override
  Future<EventReminderScheduleStatus> schedule(Event event) async {
    return EventReminderScheduleStatus.scheduled;
  }
}

class _RecordingEventWidgetUpdater implements EventWidgetUpdater {
  @override
  Future<void> updateCurrentWeek(
    List<Event> events, {
    required AppThemePreset theme,
    DateTime? now,
  }) async {}

  @override
  Future<void> updateStatus(String message) async {}

  @override
  Future<void> updateTheme(AppThemePreset theme) async {}
}

class _MemoryCredentialStore implements AiCredentialStore {
  @override
  bool get isAvailable => true;

  @override
  Future<void> deleteCredential(String reference) async {}

  @override
  Future<String?> readCredential(String reference) async => null;

  @override
  Future<String> saveCredential(String credential) async {
    return 'secure-storage:test';
  }
}
