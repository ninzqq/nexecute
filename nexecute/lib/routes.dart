import 'package:nexecute/count/countpage.dart';
import 'package:nexecute/home/home.dart';
import 'package:nexecute/loadingscreen/loadingscreen.dart';
import 'package:nexecute/profile/profile.dart';

var appRoutes = {
  "/": (context) => const LoadingScreen(),
  "/home": (context) => const HomeScreen(),
  "/profile": (context) => const ProfileScreen(),
  "/count": (context) => const CountPage(),
};
