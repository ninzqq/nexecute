import 'package:flutter/material.dart';

class HomeTabIndex with ChangeNotifier {
  int idx;
  HomeTabIndex({this.idx = 2});

  void changeIndex(int index) {
    idx = index;
    notifyListeners();
  }
}
