import 'package:nexecute/count/countscreen.dart';
import 'package:nexecute/home/homescreen.dart';
import 'package:nexecute/loadingscreen/loadingscreen.dart';
import 'package:nexecute/profile/profilescreen.dart';

var appRoutes = {
  "/": (context) => const LoadingScreen(),
  "/home": (context) => const HomeScreen(),
  "/profile": (context) => const ProfileScreen(),
  "/count": (context) => const CountScreen(),
};
