import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalendarSettingsController with ChangeNotifier {
  CalendarSettingsController({bool showWeekNumbers = true})
    : _showWeekNumbers = showWeekNumbers;

  static const _showWeekNumbersKey = 'calendar_show_week_numbers';

  bool _showWeekNumbers;

  bool get showWeekNumbers => _showWeekNumbers;

  static Future<CalendarSettingsController> load() async {
    final preferences = await SharedPreferences.getInstance();
    return CalendarSettingsController(
      showWeekNumbers: preferences.getBool(_showWeekNumbersKey) ?? true,
    );
  }

  Future<void> setShowWeekNumbers(bool value) async {
    if (_showWeekNumbers == value) return;

    _showWeekNumbers = value;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_showWeekNumbersKey, value);
  }
}
