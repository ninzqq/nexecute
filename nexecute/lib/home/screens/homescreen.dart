import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nexecute/home/widgets/executeslist.dart';
import 'package:nexecute/services/services.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  HomeScreen({Key? key}) : super(key: key);

  final PageController pageController = PageController(initialPage: 1);

  @override
  Widget build(BuildContext context) {
    var asdf = Provider.of<Asdf>(context, listen: true);
    var homePageIndex = Provider.of<HomeTabIndex>(context, listen: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quicxecs'),
        backgroundColor: appBarDarkCyan,
      ),
      drawer: const MainDrawer(),
      body: Stack(
        children: [
          PageView(
            controller: pageController,
            onPageChanged: (page) {
              homePageIndex.changeIndex(page);
            },
            children: [
              Container(
                color: bgDarkerCyan,
                child: const Center(
                  child: Text('First'),
                ),
              ),
              const Quicxecs(),
            ],
          ),
          BottomNavBar(
            changePage: pageController.animateToPage,
          ),
        ],
      ),
    );
  }
}
