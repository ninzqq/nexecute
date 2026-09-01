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
        aiCredentialStore:
            (macOSCredentialStoreFactory ??
                    FlutterSecureAiCredentialStore.macOS)
                .call(),
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

  return AppPlatformServices(
    platform: AppRuntimePlatform.android,
    reminderScheduler: reminderScheduler,
    eventWidgetUpdater: (androidWidgetFactory ?? EventWidgetService.new).call(),
    aiCredentialStore:
        (androidCredentialStoreFactory ?? FlutterSecureAiCredentialStore.new)
            .call(),
  );
}
