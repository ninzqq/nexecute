import 'dart:async';

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
  final platformServices = await createDefaultAppPlatformServices();
  runApp(
    Nexecute(
      themeController: themeController,
      calendarSettingsController: calendarSettingsController,
      platformServices: platformServices,
    ),
  );
}

class Nexecute extends StatefulWidget {
  const Nexecute({
    super.key,
    this.themeController,
    this.calendarSettingsController,
    this.platformServices,
  });

  final AppThemeController? themeController;
  final CalendarSettingsController? calendarSettingsController;
  final AppPlatformServices? platformServices;

  // Create the initialization Future outside of `build`:
  @override
  NexecuteState createState() => NexecuteState();
}

class NexecuteState extends State<Nexecute> {
  late final AppThemeController _themeController;
  late final bool _ownsThemeController;
  late final CalendarSettingsController _calendarSettingsController;
  late final bool _ownsCalendarSettingsController;
  late final AppPlatformServices _platformServices;

  @override
  void initState() {
    super.initState();
    _ownsThemeController = widget.themeController == null;
    _themeController = widget.themeController ?? AppThemeController();
    _ownsCalendarSettingsController = widget.calendarSettingsController == null;
    _calendarSettingsController =
        widget.calendarSettingsController ?? CalendarSettingsController();
    _platformServices =
        widget.platformServices ?? AppPlatformServices.unsupported;
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
        Provider<EventReminderScheduler>.value(
          value: _platformServices.reminderScheduler,
        ),
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
            return WidgetSyncingEventRepository(
              delegate: repository,
              widgetService: _platformServices.eventWidgetUpdater,
              themePreset: () => _themeController.preset,
            );
          },
        ),
        Provider<TodoRepository>(
          create:
              (context) => FirestoreTodoRepository(
                authService: context.read<AuthService>(),
              ),
        ),
        Provider<AiApplicationContextReadService>(
          create:
              (context) => RepositoryBackedAiApplicationContextReadService(
                todoRepository: context.read<TodoRepository>(),
                eventRepository: context.read<EventRepository>(),
                noteRepository: context.read<NoteRepository>(),
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
        Provider<AiCredentialStore>.value(
          value: _platformServices.aiCredentialStore,
        ),
        Provider<AiAssistantRepository>(
          create:
              (context) => OpenAiCompatibleAssistantRepository(
                credentialStore: context.read<AiCredentialStore>(),
              ),
          dispose:
              (_, repository) =>
                  (repository as OpenAiCompatibleAssistantRepository).dispose(),
        ),
        Provider<AiConnectionProfileStore>(
          create: (_) => SharedPreferencesAiConnectionProfileStore(),
          dispose: (_, store) => store.dispose(),
        ),
        Provider<AiConversationStore>(
          create:
              (context) => FirestoreAiConversationStore(
                authService: context.read<AuthService>(),
              ),
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
    unawaited(() async {
      try {
        await _platformServices.eventWidgetUpdater.updateTheme(
          _themeController.preset,
        );
      } catch (_) {
        // A launcher without widget support must not affect app theming.
      }
    }());
  }
}
