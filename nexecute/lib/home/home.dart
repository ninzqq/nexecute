import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nexecute/home/executepageview.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedPage = 1;
  final PageController _pageController = PageController(initialPage: 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Execs'),
      ),
      drawer: const MainDrawer(),
      body: PageView(
        controller: _pageController,
        onPageChanged: (page) {
          setState(() {
            _selectedPage = page;
          });
        },
        children: const [
          Center(
            child: Text('First'),
          ),
          Center(
            child: Text('Second'),
          ),
          Center(
            child: Text('Third'),
          ),
        ],
      ),
      bottomNavigationBar: SizedBox(
        height: 46,
        child: BottomNavigationBar(
          currentIndex: _selectedPage,
          selectedItemColor: const Color.fromARGB(255, 32, 160, 160),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(
                FontAwesomeIcons.calendarDays,
                size: 15,
              ),
              label: 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                FontAwesomeIcons.listCheck,
                size: 15,
              ),
              label: 'Execs',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                FontAwesomeIcons.userAstronaut,
                size: 15,
              ),
              label: 'Profile',
            ),
          ],
          onTap: (int idx) {
            setState(() {
              _selectedPage = idx;
            });
            _pageController.jumpToPage(idx);
          },
        ),
      ),
    );
  }
}
