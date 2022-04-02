import 'package:flutter/material.dart';
import 'package:nexecute/count/countpage.dart';
import 'package:nexecute/home/executepageview.dart';
import 'package:nexecute/shared/shared.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Execs'),
      ),
      drawer: const MainDrawer(),
      body: const CountPage(),
      //bottomNavigationBar: const BottomNavBar(
      //  pageIndex: 1,
      //),
    );
  }
}
