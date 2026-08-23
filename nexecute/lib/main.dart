import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nexecute/models/selected_day.dart';
import 'package:nexecute/models/app_theme_controller.dart';
import 'package:nexecute/services/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'package:nexecute/routes.dart';
import 'package:nexecute/models/home_tab_index.dart';
import 'package:nexecute/models/count.dart';
import 'package:nexecute/models/quicxec_column_count.dart';
import 'package:nexecute/models/asdf.dart';
import 'package:nexecute/models/quicxec.dart';
import 'package:nexecute/models/event.dart';
import 'package:nexecute/models/tag.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final themeController = await AppThemeController.load();
  runApp(Nexecute(themeController: themeController));
}

/// We are using a StatefulWidget such that we only create the [Future] once,
/// no matter how many times our widget rebuild.
/// If we used a [StatelessWidget], in the event where [App] is rebuilt, that
/// would re-initialize FlutterFire and make our application re-enter loading state,
/// which is undesired.
class Nexecute extends StatefulWidget {
  const Nexecute({super.key, this.themeController});

  final AppThemeController? themeController;

  // Create the initialization Future outside of `build`:
  @override
  NexecuteState createState() => NexecuteState();
}

class NexecuteState extends State<Nexecute> {
  /// The future is part of the state of our widget. We should not call `initializeApp`
  /// directly inside [build].
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();
  late final AppThemeController _themeController;
  late final bool _ownsThemeController;

  @override
  void initState() {
    super.initState();
    _ownsThemeController = widget.themeController == null;
    _themeController = widget.themeController ?? AppThemeController();
  }

  @override
  void dispose() {
    if (_ownsThemeController) _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print(kIsWeb);
    print(defaultTargetPlatform);
    return FutureBuilder(
      // Initialize FlutterFire:
      future: _initialization,
      builder: (context, snapshot) {
        // Check for errors
        if (snapshot.hasError) {
          return const Text('error');
        }

        // Once complete, show your application
        if (snapshot.connectionState == ConnectionState.done) {
          return MultiProvider(
            providers: [
              StreamProvider<Count>(
                create: (_) => FirestoreService().streamCount(),
                initialData: Count(),
                catchError: (_, err) => Count(),
              ),
              StreamProvider<List<Quicxec>>(
                create: (_) => FirestoreService().streamQuicxecs(),
                initialData: const [],
                catchError: (_, err) => [],
              ),
              StreamProvider<List<Event>>(
                create: (_) => FirestoreService().streamEvents(),
                initialData: const [],
                catchError: (_, err) => [],
              ),
              StreamProvider<Tags>(
                create: (_) => FirestoreService().streamTags(),
                initialData: Tags(),
                catchError: (_, err) => Tags(),
              ),
              ChangeNotifierProvider(
                create: (context) => QuicxecsColumnCount(),
              ),
              ChangeNotifierProvider(create: (context) => Asdf()),
              ChangeNotifierProvider(create: (context) => HomeTabIndex()),
              ChangeNotifierProvider(create: (context) => SelectedDay()),
              ChangeNotifierProvider.value(value: _themeController),
            ],
            child: Consumer<AppThemeController>(
              builder:
                  (context, themeController, _) =>
                      defaultTargetPlatform == TargetPlatform.android
                          ? MaterialApp(
                            routes: appRoutes,
                            theme: themeController.themeData,
                            localizationsDelegates:
                                GlobalMaterialLocalizations.delegates,
                            supportedLocales: [const Locale('fi', 'FI')],
                          )
                          : kIsWeb
                          ? const Text(
                            'WEEEEEEEEB',
                            textDirection: TextDirection.ltr,
                          )
                          : const Center(
                            child: Text(
                              'JOTAI VITUN MUUUTAAAAAA',
                              textDirection: TextDirection.ltr,
                            ),
                          ),
            ),
          );
        }

        // Otherwise, show something whilst waiting for initialization to complete
        return const Center(
          child: Text('loading', textDirection: TextDirection.ltr),
        );
      },
    );
  }
}
