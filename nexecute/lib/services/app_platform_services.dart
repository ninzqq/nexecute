import 'package:flutter/foundation.dart';
import 'package:nexecute/ai/infrastructure/flutter_secure_ai_credential_store.dart';
import 'package:nexecute/ai/repositories/ai_credential_store.dart';
import 'package:nexecute/services/event_reminder_scheduler.dart';
import 'package:nexecute/services/event_widget_service.dart';

enum AppRuntimePlatform { android, macOS, web, unsupported }

final class AppPlatformServices {
  const AppPlatformServices({
    required this.platform,
    required this.reminderScheduler,
    required this.eventWidgetUpdater,
    required this.aiCredentialStore,
  });

  static const web = AppPlatformServices(
    platform: AppRuntimePlatform.web,
    reminderScheduler: NoopEventReminderScheduler(),
    eventWidgetUpdater: NoopEventWidgetUpdater(),
    aiCredentialStore: UnavailableAiCredentialStore(),
  );

  static const unsupported = AppPlatformServices(
    platform: AppRuntimePlatform.unsupported,
    reminderScheduler: NoopEventReminderScheduler(),
    eventWidgetUpdater: NoopEventWidgetUpdater(),
    aiCredentialStore: UnavailableAiCredentialStore(),
  );

  final AppRuntimePlatform platform;
  final EventReminderScheduler reminderScheduler;
  final EventWidgetUpdater eventWidgetUpdater;
  final AiCredentialStore aiCredentialStore;
}

AppRuntimePlatform resolveAppRuntimePlatform({
  required bool isWeb,
  required TargetPlatform targetPlatform,
}) {
  if (isWeb) return AppRuntimePlatform.web;
  return switch (targetPlatform) {
    TargetPlatform.android => AppRuntimePlatform.android,
    TargetPlatform.macOS => AppRuntimePlatform.macOS,
    _ => AppRuntimePlatform.unsupported,
  };
}

Future<AppPlatformServices> createDefaultAppPlatformServices() {
  return createAppPlatformServices(
    resolveAppRuntimePlatform(
      isWeb: kIsWeb,
      targetPlatform: defaultTargetPlatform,
    ),
  );
}

Future<AppPlatformServices> createAppPlatformServices(
  AppRuntimePlatform platform, {
  Future<EventReminderScheduler> Function()? androidReminderInitializer,
  EventWidgetUpdater Function()? androidWidgetFactory,
  AiCredentialStore Function()? androidCredentialStoreFactory,
  AiCredentialStore Function()? macOSCredentialStoreFactory,
}) async {
  switch (platform) {
    case AppRuntimePlatform.macOS:
      return AppPlatformServices(
        platform: AppRuntimePlatform.macOS,
        reminderScheduler: const NoopEventReminderScheduler(),
        eventWidgetUpdater: const NoopEventWidgetUpdater(),
        aiCredentialStore: _createOptionalService(
          macOSCredentialStoreFactory ?? FlutterSecureAiCredentialStore.macOS,
          fallback: const UnavailableAiCredentialStore(),
        ),
      );
    case AppRuntimePlatform.web:
      return AppPlatformServices.web;
    case AppRuntimePlatform.unsupported:
      return AppPlatformServices.unsupported;
    case AppRuntimePlatform.android:
      break;
  }

  final initializeReminder =
      androidReminderInitializer ?? AndroidEventReminderScheduler.initialize;
  EventReminderScheduler reminderScheduler;
  try {
    reminderScheduler = await initializeReminder();
  } catch (_) {
    reminderScheduler = const NoopEventReminderScheduler();
  }

  final eventWidgetUpdater = _createOptionalService(
    androidWidgetFactory ?? EventWidgetService.new,
    fallback: const NoopEventWidgetUpdater(),
  );
  final aiCredentialStore = _createOptionalService(
    androidCredentialStoreFactory ?? FlutterSecureAiCredentialStore.new,
    fallback: const UnavailableAiCredentialStore(),
  );

  return AppPlatformServices(
    platform: AppRuntimePlatform.android,
    reminderScheduler: reminderScheduler,
    eventWidgetUpdater: eventWidgetUpdater,
    aiCredentialStore: aiCredentialStore,
  );
}

T _createOptionalService<T>(T Function() create, {required T fallback}) {
  try {
    return create();
  } catch (_) {
    return fallback;
  }
}
