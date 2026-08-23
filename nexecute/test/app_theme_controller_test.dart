import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexecute/models/app_theme_controller.dart';
import 'package:nexecute/themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('uses Midnight when no preference has been saved', () async {
    final controller = await AppThemeController.load();

    expect(controller.preset, AppThemePreset.midnight);
  });

  test('persists the selected theme', () async {
    final controller = await AppThemeController.load();

    await controller.select(AppThemePreset.cyberpunk);
    final restoredController = await AppThemeController.load();

    expect(restoredController.preset, AppThemePreset.cyberpunk);
  });

  test('restores the Neutral theme', () async {
    final controller = await AppThemeController.load();

    await controller.select(AppThemePreset.neutral);
    final restoredController = await AppThemeController.load();

    expect(restoredController.preset, AppThemePreset.neutral);
  });

  test('each preset has a distinct primary color', () {
    final primaryColors = {
      for (final preset in AppThemePreset.values)
        AppThemes.forPreset(preset).colorScheme.primary,
    };

    expect(primaryColors.length, AppThemePreset.values.length);
  });

  test('Cyberpunk navigation uses dark chrome and cyan selection', () {
    final theme = AppThemes.forPreset(AppThemePreset.cyberpunk);
    final navigationTheme = theme.navigationBarTheme;

    expect(navigationTheme.backgroundColor, const Color(0xFF120A25));
    expect(navigationTheme.indicatorColor, const Color(0xFF241437));
    expect(
      navigationTheme.iconTheme?.resolve({WidgetState.selected})?.color,
      const Color(0xFF00E7F0),
    );
    expect(navigationTheme.elevation, 8);
    expect(navigationTheme.shadowColor, isNot(Colors.transparent));
  });
}
