import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:nexecute/routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const Nexecute());
}

/// We are using a StatefulWidget such that we only create the [Future] once,
/// no matter how many times our widget rebuild.
/// If we used a [StatelessWidget], in the event where [App] is rebuilt, that
/// would re-initialize FlutterFire and make our application re-enter loading state,
/// which is undesired.
class Nexecute extends StatefulWidget {
  const Nexecute({Key? key}) : super(key: key);

  // Create the initialization Future outside of `build`:
  @override
  _NexecuteState createState() => _NexecuteState();
}

class _NexecuteState extends State<Nexecute> {
  /// The future is part of the state of our widget. We should not call `initializeApp`
  /// directly inside [build].
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();

  @override
  Widget build(BuildContext context) {
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
          //return StreamProvider(
          //  create: (_) => FirestoreService().streamReport(),
          //  catchError: (_, err) => Report(),
          //  initialData: [],
          //  child: MaterialApp(
          //    routes: appRoutes,
          //    theme: appTheme,
          //  ),
          //);
          return MaterialApp(
            routes: appRoutes,
          );
        }

        // Otherwise, show something whilst waiting for initialization to complete
        return const Center(
            child: Text('loading', textDirection: TextDirection.ltr));
      },
    );
  }
}