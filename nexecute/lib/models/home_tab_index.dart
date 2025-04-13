import 'package:flutter/material.dart';

class HomeTabIndex with ChangeNotifier {
  int idx;
  HomeTabIndex({
    this.idx = 1,
  });

  void changeIndex(index) {
    idx = index;
    notifyListeners();
  }
}