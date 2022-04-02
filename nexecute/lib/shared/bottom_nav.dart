import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nexecute/home/executepageview.dart';

class BottomNavBar extends StatelessWidget {
  final int pageIndex;

  const BottomNavBar({Key? key, required this.pageIndex}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: pageIndex,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(
            FontAwesomeIcons.calendarDays,
            size: 20,
          ),
          label: 'Calendar',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            FontAwesomeIcons.listCheck,
            size: 20,
          ),
          label: 'Execs',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            FontAwesomeIcons.userAstronaut,
            size: 20,
          ),
          label: 'Profile',
        ),
      ],
      onTap: (int idx) {
        if (idx != pageIndex) {
          switch (idx) {
            case 0:
              Navigator.popAndPushNamed(context, '/calendar');
              break;
            case 1:
              Navigator.popAndPushNamed(context, '/home');
              break;
            case 2:
              Navigator.popAndPushNamed(context, '/profile');
              break;
          }
        }
      },
    );
  }
}
