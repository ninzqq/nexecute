import 'package:flutter/material.dart';

class SelectedDay with ChangeNotifier {
  SelectedDay({
    DateTime? selectedDay,
  }) : _selectedDay = selectedDay ?? DateTime.now();

  DateTime _selectedDay;

  DateTime get selectedDay => _selectedDay;

  void setSelectedDay(DateTime newSelectedDay) {
    _selectedDay = newSelectedDay;
    print('Selected day set to: $_selectedDay');
    notifyListeners();
  }
}