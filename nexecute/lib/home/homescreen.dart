import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nexecute/services/models.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  HomeScreen({Key? key}) : super(key: key);

  final PageController _pageController = PageController(initialPage: 1);

  @override
  Widget build(BuildContext context) {
    var asdf = Provider.of<Asdf>(context, listen: true);
    var homePageIndex = Provider.of<HomeTabIndex>(context, listen: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Execs'),
      ),
      drawer: const MainDrawer(),
      body: PageView(
        controller: _pageController,
        onPageChanged: (page) {
          homePageIndex.changeIndex(page);
        },
        children: [
          const Center(
            child: Text('First'),
          ),
          Center(
            child: Column(
              children: [
                Text(asdf.asd.toString()),
                FloatingActionButton(onPressed: asdf.incAsd)
              ],
            ),
          ),
          const Center(
            child: Text('Third'),
          ),
        ],
      ),
      bottomNavigationBar: SizedBox(
        height: 46,
        child: BottomNavigationBar(
          currentIndex: homePageIndex.idx,
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
            homePageIndex.changeIndex(idx);
            _pageController.jumpToPage(idx);
          },
        ),
      ),
    );
  }
}
