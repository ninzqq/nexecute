import 'package:nexecute/count/countscreen.dart';
import 'package:nexecute/home/home.dart';
import 'package:nexecute/home/screens/tagsscreen.dart';
import 'package:nexecute/userloginstatuscheck/userloginstatuscheck.dart';
import 'package:nexecute/profile/profilescreen.dart';

var appRoutes = {
  "/": (context) => const UserLogInStatusCheck(),
  "/home": (context) => HomeScreen(),
  "/profile": (context) => const ProfileScreen(),
  "/count": (context) => const CountScreen(),
  //"/addnewquicxec": (context) => const AddNewQuicxecScreen(),
  "/settings": (context) => const SettingsScreen(),
  "/trash": (context) => const TrashScreen(),
  "/tags": (context) => const TagsScreen(),
};
