import 'package:nexecute/home/screens/homescreen.dart';
import 'package:nexecute/home/screens/settingsscreen.dart';
import 'package:nexecute/home/screens/tagsscreen.dart';
import 'package:nexecute/home/screens/trashscreen.dart';
import 'package:nexecute/userloginstatuscheck/userloginstatuscheck.dart';
import 'package:nexecute/profile/profilescreen.dart';
import 'package:nexecute/search/unified_search_page.dart';

var appRoutes = {
  "/": (context) => const UserLogInStatusCheck(),
  "/home": (context) => HomeScreen(),
  "/profile": (context) => const ProfileScreen(),
  "/settings": (context) => const SettingsScreen(),
  "/trash": (context) => const TrashScreen(),
  "/tags": (context) => const TagsScreen(),
  "/search": (context) => const UnifiedSearchPage(),
};
