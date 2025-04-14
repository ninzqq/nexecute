import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nexecute/services/services.dart';
import 'package:nexecute/themes.dart';
import 'package:provider/provider.dart';
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
  runApp(const Nexecute());
}

/// We are using a StatefulWidget such that we only create the [Future] once,
/// no matter how many times our widget rebuild.
/// If we used a [StatelessWidget], in the event where [App] is rebuilt, that
/// would re-initialize FlutterFire and make our application re-enter loading state,
/// which is undesired.
class Nexecute extends StatefulWidget {
  const Nexecute({super.key});

  // Create the initialization Future outside of `build`:
  @override
  NexecuteState createState() => NexecuteState();
}

class NexecuteState extends State<Nexecute> {
  /// The future is part of the state of our widget. We should not call `initializeApp`
  /// directly inside [build].
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();

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
            ],
            child:
                defaultTargetPlatform == TargetPlatform.android
                    ? MaterialApp(routes: appRoutes, theme: appTheme)
                    : kIsWeb
                    ? const Text('WEEEEEEEEB', textDirection: TextDirection.ltr)
                    : const Center(
                      child: Text(
                        'JOTAI VITUN MUUUTAAAAAA',
                        textDirection: TextDirection.ltr,
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
