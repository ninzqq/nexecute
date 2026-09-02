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

  test('restores the Cyberpunk Mega theme', () async {
    final controller = await AppThemeController.load();

    await controller.select(AppThemePreset.cyberpunkMega);
    final restoredController = await AppThemeController.load();

    expect(restoredController.preset, AppThemePreset.cyberpunkMega);
  });

  test('each preset has a distinct primary color', () {
    final primaryColors = {
      for (final preset in AppThemePreset.values)
        AppThemes.forPreset(preset).colorScheme.primary,
    };

    expect(primaryColors.length, AppThemePreset.values.length);
  });

  test('Cyberpunk uses cyan as its primary interactive accent', () {
    final theme = AppThemes.forPreset(AppThemePreset.cyberpunk);
    final navigationTheme = theme.navigationBarTheme;
    final navigationRailTheme = theme.navigationRailTheme;

    expect(theme.colorScheme.primary, const Color(0xFF00E7F0));
    expect(theme.colorScheme.secondary, const Color(0xFFFF3BD4));
    expect(
      theme.floatingActionButtonTheme.backgroundColor,
      const Color(0xFF00E7F0),
    );
    expect(navigationTheme.backgroundColor, const Color(0xFF120A25));
    expect(navigationTheme.indicatorColor, const Color(0xFF102A35));
    expect(
      navigationTheme.iconTheme?.resolve({WidgetState.selected})?.color,
      const Color(0xFF00E7F0),
    );
    expect(
      navigationTheme.labelTextStyle?.resolve({WidgetState.selected})?.color,
      const Color(0xFFFF3BD4),
    );
    expect(
      (navigationTheme.indicatorShape as StadiumBorder).side.color,
      const Color(0xFFFF3BD4).withValues(alpha: 0.75),
    );
    expect(navigationRailTheme.backgroundColor, const Color(0xFF120A25));
    expect(navigationRailTheme.indicatorColor, const Color(0xFF102A35));
    expect(
      navigationRailTheme.selectedIconTheme?.color,
      const Color(0xFF00E7F0),
    );
    expect(
      navigationRailTheme.selectedLabelTextStyle?.color,
      const Color(0xFFFF3BD4),
    );
    expect(
      (navigationRailTheme.indicatorShape as StadiumBorder).side.color,
      const Color(0xFFFF3BD4).withValues(alpha: 0.75),
    );
    expect(
      (theme.floatingActionButtonTheme.shape as CircleBorder).side.color,
      const Color(0xFFFF3BD4),
    );
    expect(navigationTheme.elevation, 8);
    expect(navigationTheme.shadowColor, isNot(Colors.transparent));
  });

  test('Cyberpunk Mega uses the graphite neon reference palette', () {
    final theme = AppThemes.forPreset(AppThemePreset.cyberpunkMega);
    final palette = theme.extension<AppPalette>()!;
    final navigationTheme = theme.navigationBarTheme;

    expect(palette.background, const Color(0xFF05070C));
    expect(palette.surface, const Color(0xFF0D0C14));
    expect(palette.surfaceRaised, const Color(0xFF111821));
    expect(palette.chrome, const Color(0xFF100E18));
    expect(theme.colorScheme.primary, const Color(0xFF00D7E5));
    expect(theme.colorScheme.secondary, const Color(0xFFD83ADB));
    expect(theme.colorScheme.tertiary, const Color(0xFF7928CA));
    expect(theme.colorScheme.onSurface, const Color(0xFF00D7E5));
    expect(theme.colorScheme.onSurfaceVariant, const Color(0xFF008E98));
    expect(palette.outline, const Color(0xFF7226A8));
    expect(navigationTheme.indicatorColor, const Color(0xFF21102D));
    expect(
      navigationTheme.labelTextStyle?.resolve({WidgetState.selected})?.color,
      const Color(0xFFD83ADB),
    );
    expect(
      (navigationTheme.indicatorShape as StadiumBorder).side.color,
      const Color(0xFFD83ADB).withValues(alpha: 0.75),
    );
  });
}
