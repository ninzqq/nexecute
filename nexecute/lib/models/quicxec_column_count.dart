import 'package:flutter/material.dart';

class QuicxecsColumnCount extends ChangeNotifier {
  int columnCount;

  int get columns {
    return columnCount;
  }

  set columns(int columns) {
    columnCount = columns;
    notifyListeners();
  }

  QuicxecsColumnCount({this.columnCount = 1});
}
