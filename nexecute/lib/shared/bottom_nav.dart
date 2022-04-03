import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nexecute/home/executepageview.dart';
import 'package:nexecute/home/homescreen.dart';
import 'package:provider/provider.dart';

class BottomNavBar extends StatelessWidget {
  final int pageIndex;

  const BottomNavBar({Key? key, required this.pageIndex}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int _selectedPage = 0;
    return BottomNavigationBar(
      currentIndex: _selectedPage,
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
        _selectedPage = idx;
      },
    );
  }
}
