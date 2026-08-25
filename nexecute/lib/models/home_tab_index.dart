import 'package:flutter/foundation.dart';

class HomeTabIndex with ChangeNotifier {
  HomeTabIndex({int initialIndex = 2}) : _index = initialIndex;

  int _index;

  int get index => _index;

  void select(int index) {
    if (_index == index) return;
    _index = index;
    notifyListeners();
  }
}
