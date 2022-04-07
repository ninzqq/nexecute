import 'package:nexecute/count/countscreen.dart';
import 'package:nexecute/home/home.dart';
import 'package:nexecute/loadingscreen/loadingscreen.dart';
import 'package:nexecute/profile/profilescreen.dart';

var appRoutes = {
  "/": (context) => const LoadingScreen(),
  "/home": (context) => HomeScreen(),
  "/profile": (context) => const ProfileScreen(),
  "/count": (context) => const CountScreen(),
  "/newtask": (context) => const CreateNewTaskScreen(),
};
