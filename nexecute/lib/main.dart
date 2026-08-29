import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nexecute/ai/ai.dart';
import 'package:nexecute/models/selected_day.dart';
import 'package:nexecute/models/app_theme_controller.dart';
import 'package:nexecute/models/calendar_settings_controller.dart';
import 'package:nexecute/repositories/repositories.dart';
import 'package:nexecute/services/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'package:nexecute/routes.dart';
import 'package:nexecute/models/home_tab_index.dart';
import 'package:nexecute/models/notes_controller.dart';
import 'package:nexecute/models/data_state.dart';
import 'package:nexecute/models/note_folder.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/tag.dart';
import 'package:nexecute/models/todo_item.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final themeController = await AppThemeController.load();
  final calendarSettingsController = await CalendarSettingsController.load();
  final reminderScheduler = await createDefaultEventReminderScheduler();
  final eventWidgetService =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? EventWidgetService()
          : null;
  runApp(
    Nexecute(
      themeController: themeController,
      calendarSettingsController: calendarSettingsController,
      reminderScheduler: reminderScheduler,
      eventWidgetService: eventWidgetService,
    ),
  );
}

class Nexecute extends StatefulWidget {
  const Nexecute({
    super.key,
    this.themeController,
    this.calendarSettingsController,
    this.reminderScheduler,
    this.eventWidgetService,
  });

  final AppThemeController? themeController;
  final CalendarSettingsController? calendarSettingsController;
  final EventReminderScheduler? reminderScheduler;
  final EventWidgetService? eventWidgetService;

  // Create the initialization Future outside of `build`:
  @override
  NexecuteState createState() => NexecuteState();
}

class NexecuteState extends State<Nexecute> {
  late final AppThemeController _themeController;
  late final bool _ownsThemeController;
  late final CalendarSettingsController _calendarSettingsController;
  late final bool _ownsCalendarSettingsController;
  late final EventReminderScheduler _reminderScheduler;
  EventWidgetService? _eventWidgetService;

  @override
  void initState() {
    super.initState();
    _ownsThemeController = widget.themeController == null;
    _themeController = widget.themeController ?? AppThemeController();
    _ownsCalendarSettingsController = widget.calendarSettingsController == null;
    _calendarSettingsController =
        widget.calendarSettingsController ?? CalendarSettingsController();
    _reminderScheduler =
        widget.reminderScheduler ?? const NoopEventReminderScheduler();
    _eventWidgetService = widget.eventWidgetService;
    _themeController.addListener(_updateEventWidgetTheme);
  }

  @override
  void dispose() {
    _themeController.removeListener(_updateEventWidgetTheme);
    if (_ownsThemeController) _themeController.dispose();
    if (_ownsCalendarSettingsController) {
      _calendarSettingsController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<EventReminderScheduler>.value(value: _reminderScheduler),
        StreamProvider<DataState<User>>(
          create:
              (context) => context.read<AuthService>().watchAuthentication(),
          initialData: const DataLoading<User>(),
        ),
        Provider<NoteRepository>(
          create:
              (context) => FirestoreNoteRepository(
                authService: context.read<AuthService>(),
              ),
        ),
        Provider<NoteFolderRepository>(
          create:
              (context) => FirestoreNoteFolderRepository(
                authService: context.read<AuthService>(),
              ),
        ),
        Provider<EventRepository>(
          create: (context) {
            final firestoreRepository = FirestoreEventRepository(
              authService: context.read<AuthService>(),
            );
            EventRepository repository = ReminderSchedulingEventRepository(
              delegate: firestoreRepository,
              reminderScheduler: context.read<EventReminderScheduler>(),
            );
            final eventWidgetService = _eventWidgetService;
            if (eventWidgetService != null) {
              repository = WidgetSyncingEventRepository(
                delegate: repository,
                widgetService: eventWidgetService,
                themePreset: () => _themeController.preset,
              );
            }
            return repository;
          },
        ),
        Provider<TodoRepository>(
          create:
              (context) => FirestoreTodoRepository(
                authService: context.read<AuthService>(),
              ),
        ),
        Provider<TagRepository>(
          create:
              (context) => FirestoreTagRepository(
                authService: context.read<AuthService>(),
              ),
        ),
        Provider<ItemConversionService>(
          create:
              (context) => ItemConversionService(
                eventRepository: context.read<EventRepository>(),
                noteRepository: context.read<NoteRepository>(),
              ),
        ),
        Provider<AiAssistantRepository>(
          create: (_) => const UnconfiguredAiAssistantRepository(),
        ),
        Provider<AiConnectionProfileStore>(
          create: (_) => SharedPreferencesAiConnectionProfileStore(),
          dispose: (_, store) => store.dispose(),
        ),
        Provider<AiConversationStore>(
          create: (_) => InMemoryAiConversationStore(),
          dispose: (_, store) => store.dispose(),
        ),
        StreamProvider<DataState<List<Quicxec>>>(
          create: (context) => context.read<NoteRepository>().watchNotes(),
          initialData: const DataLoading<List<Quicxec>>(),
        ),
        StreamProvider<DataState<List<NoteFolder>>>(
          create:
              (context) => context.read<NoteFolderRepository>().watchFolders(),
          initialData: const DataLoading<List<NoteFolder>>(),
        ),
        StreamProvider<DataState<List<TodoItem>>>(
          create: (context) => context.read<TodoRepository>().watchTodos(),
          initialData: const DataLoading<List<TodoItem>>(),
        ),
        StreamProvider<DataState<Tags>>(
          create: (context) => context.read<TagRepository>().watchTags(),
          initialData: const DataLoading<Tags>(),
        ),
        ChangeNotifierProvider(create: (_) => HomeTabIndex()),
        ChangeNotifierProvider(create: (_) => NotesController()),
        ChangeNotifierProvider(create: (_) => SelectedDay()),
        ChangeNotifierProvider.value(value: _themeController),
        ChangeNotifierProvider.value(value: _calendarSettingsController),
      ],
      child: Consumer<AppThemeController>(
        builder:
            (context, themeController, _) => MaterialApp(
              routes: appRoutes,
              theme: themeController.themeData,
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              supportedLocales: const [Locale('fi', 'FI')],
            ),
      ),
    );
  }

  void _updateEventWidgetTheme() {
    final eventWidgetService = _eventWidgetService;
    if (eventWidgetService == null) return;

    unawaited(() async {
      try {
        await eventWidgetService.updateTheme(_themeController.preset);
      } catch (_) {
        // A launcher without widget support must not affect app theming.
      }
    }());
  }
}
