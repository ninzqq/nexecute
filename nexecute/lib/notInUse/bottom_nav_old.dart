import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class BottomNavBarOld extends StatelessWidget {
  final int pageIndex;

  const BottomNavBarOld({super.key, required this.pageIndex});

  @override
  Widget build(BuildContext context) {
    int selectedPage = 0;
    return BottomNavigationBar(
      currentIndex: selectedPage,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(FontAwesomeIcons.calendarDays, size: 20),
          label: 'Calendar',
        ),
        BottomNavigationBarItem(
          icon: Icon(FontAwesomeIcons.listCheck, size: 20),
          label: 'Execs',
        ),
        BottomNavigationBarItem(
          icon: Icon(FontAwesomeIcons.userAstronaut, size: 20),
          label: 'Profile',
        ),
      ],
      onTap: (int idx) {
        selectedPage = idx;
      },
    );
  }
}
