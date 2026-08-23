import 'package:flutter/material.dart';
import 'package:nexecute/home/widgets/quicxecs.dart';
import 'package:nexecute/shared/shared.dart';
import 'package:nexecute/ui/calendar/calendar.dart';

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});

  final PageController pageController = PageController(initialPage: 1);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Nexecute')),
        drawer: const MainDrawer(),
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            PageView(
              controller: pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [const CalendarPage(), const Quicxecs()],
            ),
            BottomNavBar(changePage: pageController.animateToPage),
          ],
        ),
      ),
    );
  }
}
