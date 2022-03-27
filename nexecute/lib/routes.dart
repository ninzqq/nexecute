import 'package:nexecute/home/home.dart';
import 'package:nexecute/loadingscreen/loadingscreen.dart';

var appRoutes = {
  "/": (context) => const LoadingScreen(),
  "/home": (context) => const HomeScreen(),
};
