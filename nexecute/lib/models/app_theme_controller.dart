import 'package:flutter/material.dart';
import 'package:nexecute/themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController with ChangeNotifier {
  AppThemeController({AppThemePreset preset = AppThemePreset.midnight})
    : _preset = preset;

  static const _preferenceKey = 'app_theme_preset';

  AppThemePreset _preset;

  AppThemePreset get preset => _preset;
  ThemeData get themeData => AppThemes.forPreset(_preset);

  static Future<AppThemeController> load() async {
    final preferences = await SharedPreferences.getInstance();
    final storedName = preferences.getString(_preferenceKey);
    AppThemePreset? preset;
    for (final value in AppThemePreset.values) {
      if (value.name == storedName) preset = value;
    }

    return AppThemeController(preset: preset ?? AppThemePreset.midnight);
  }

  Future<void> select(AppThemePreset preset) async {
    if (_preset == preset) return;
    _preset = preset;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, preset.name);
  }
}
