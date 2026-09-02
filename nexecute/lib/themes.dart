import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum AppThemePreset { cyberpunk, cyberpunkMega, midnight, forest, neutral }

extension AppThemePresetDetails on AppThemePreset {
  String get label => switch (this) {
    AppThemePreset.cyberpunk => 'Cyberpunk',
    AppThemePreset.cyberpunkMega => 'Cyberpunk Mega',
    AppThemePreset.midnight => 'Midnight',
    AppThemePreset.forest => 'Forest',
    AppThemePreset.neutral => 'Neutral',
  };

  String get description => switch (this) {
    AppThemePreset.cyberpunk => 'Electric magenta and cyan on deep violet',
    AppThemePreset.cyberpunkMega =>
      'Neon cyan, magenta, and ultraviolet on near-black graphite',
    AppThemePreset.midnight => 'Calm blue accents on a dark navy canvas',
    AppThemePreset.forest => 'Soft green and amber with earthy contrast',
    AppThemePreset.neutral => 'Charcoal and soft gray with minimal color',
  };

  IconData get icon => switch (this) {
    AppThemePreset.cyberpunk => Icons.bolt_rounded,
    AppThemePreset.cyberpunkMega => Icons.grid_4x4_rounded,
    AppThemePreset.midnight => Icons.nightlight_round,
    AppThemePreset.forest => Icons.forest_rounded,
    AppThemePreset.neutral => Icons.contrast_rounded,
  };
}

abstract final class AppThemes {
  static ThemeData forPreset(AppThemePreset preset) {
    final palette = _paletteFor(preset);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: Brightness.dark,
      surface: palette.surface,
    ).copyWith(
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      secondary: palette.secondary,
      tertiary: palette.tertiary,
      surface: palette.surface,
      onSurface: palette.onSurface,
      onSurfaceVariant:
          preset == AppThemePreset.cyberpunkMega
              ? const Color(0xFF008E98)
              : null,
    );

    final baseTextTheme = ThemeData.dark().textTheme.apply(
      bodyColor: palette.onSurface,
      displayColor: palette.onSurface,
    );
    final isCyberpunk =
        preset == AppThemePreset.cyberpunk ||
        preset == AppThemePreset.cyberpunkMega;
    final navigationIconAccent = palette.primary;
    final navigationLabelAccent =
        isCyberpunk ? palette.secondary : palette.primary;
    final navigationIndicator = switch (preset) {
      AppThemePreset.cyberpunk => const Color(0xFF102A35),
      AppThemePreset.cyberpunkMega => const Color(0xFF21102D),
      _ => palette.primary.withValues(alpha: 0.18),
    };
    final desktopPlatform = switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      visualDensity:
          desktopPlatform ? VisualDensity.compact : VisualDensity.standard,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.surface,
      dividerColor: palette.outline,
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: isCyberpunk ? 1.2 : 0.2,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.chrome,
        foregroundColor: palette.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          color: palette.onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: isCyberpunk ? 1.4 : 0.2,
        ),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: palette.chrome),
      cardTheme: CardThemeData(
        color: palette.surfaceRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.outline),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.outline),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.chrome,
        modalBackgroundColor: palette.chrome,
        showDragHandle: true,
      ),
      popupMenuTheme: PopupMenuThemeData(color: palette.surfaceRaised),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(palette.surfaceRaised),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              side: BorderSide(color: palette.outline),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        dense: desktopPlatform,
        minVerticalPadding: desktopPlatform ? 4 : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.primary,
        contentTextStyle: TextStyle(
          color: palette.onPrimary,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        shape: CircleBorder(
          side:
              isCyberpunk
                  ? BorderSide(color: palette.secondary, width: 1.5)
                  : BorderSide.none,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: palette.chrome,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.72),
        indicatorColor: navigationIndicator,
        indicatorShape: StadiumBorder(
          side: BorderSide(
            color:
                isCyberpunk
                    ? palette.secondary.withValues(alpha: 0.75)
                    : palette.outline,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color:
                selected
                    ? navigationIconAccent
                    : palette.onSurface.withValues(alpha: 0.65),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return baseTextTheme.labelMedium?.copyWith(
            color:
                selected
                    ? navigationLabelAccent
                    : palette.onSurface.withValues(alpha: 0.65),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: palette.chrome,
        indicatorColor: navigationIndicator,
        indicatorShape: StadiumBorder(
          side: BorderSide(
            color:
                isCyberpunk
                    ? palette.secondary.withValues(alpha: 0.75)
                    : palette.outline,
          ),
        ),
        selectedIconTheme: IconThemeData(color: navigationIconAccent),
        unselectedIconTheme: IconThemeData(
          color: palette.onSurface.withValues(alpha: 0.65),
        ),
        selectedLabelTextStyle: baseTextTheme.labelMedium?.copyWith(
          color: navigationLabelAccent,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: baseTextTheme.labelMedium?.copyWith(
          color: palette.onSurface.withValues(alpha: 0.65),
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(desktopPlatform ? 8 : 12),
          borderSide: BorderSide(color: palette.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(desktopPlatform ? 8 : 12),
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected)
                    ? palette.onPrimary
                    : palette.onSurface,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected)
                    ? palette.primary
                    : palette.surfaceRaised,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color:
                  isCyberpunk && states.contains(WidgetState.selected)
                      ? palette.secondary.withValues(alpha: 0.85)
                      : palette.outline,
              width:
                  isCyberpunk && states.contains(WidgetState.selected)
                      ? 1.5
                      : 1,
            ),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration:
            desktopPlatform
                ? const Duration(milliseconds: 450)
                : const Duration(milliseconds: 1500),
      ),
      extensions: [palette],
    );
  }

  static AppPalette _paletteFor(AppThemePreset preset) => switch (preset) {
    AppThemePreset.cyberpunk => const AppPalette(
      background: Color(0xFF080510),
      surface: Color(0xFF100B20),
      surfaceRaised: Color(0xFF1A1230),
      chrome: Color(0xFF120A25),
      primary: Color(0xFF00E7F0),
      onPrimary: Color(0xFF001F22),
      secondary: Color(0xFFFF3BD4),
      tertiary: Color(0xFFFFD740),
      onSurface: Color(0xFFF5EEFF),
      outline: Color(0xFF32556B),
      success: Color(0xFF55F991),
    ),
    AppThemePreset.cyberpunkMega => const AppPalette(
      background: Color(0xFF05070C),
      surface: Color(0xFF0D0C14),
      surfaceRaised: Color(0xFF111821),
      chrome: Color(0xFF100E18),
      primary: Color(0xFF00D7E5),
      onPrimary: Color(0xFF001E21),
      secondary: Color(0xFFD83ADB),
      tertiary: Color(0xFF7928CA),
      onSurface: Color(0xFF00D7E5),
      outline: Color(0xFF7226A8),
      success: Color(0xFF56D47B),
    ),
    AppThemePreset.midnight => const AppPalette(
      background: Color(0xFF080D17),
      surface: Color(0xFF101827),
      surfaceRaised: Color(0xFF172338),
      chrome: Color(0xFF0D1727),
      primary: Color(0xFF78A9FF),
      onPrimary: Color(0xFF06162E),
      secondary: Color(0xFF6AD7E5),
      tertiary: Color(0xFFB8A7FF),
      onSurface: Color(0xFFE8EEF8),
      outline: Color(0xFF334561),
      success: Color(0xFF73D7A5),
    ),
    AppThemePreset.forest => const AppPalette(
      background: Color(0xFF07110D),
      surface: Color(0xFF0E1D17),
      surfaceRaised: Color(0xFF162A21),
      chrome: Color(0xFF0B1913),
      primary: Color(0xFF72D6A0),
      onPrimary: Color(0xFF052015),
      secondary: Color(0xFFE1B866),
      tertiary: Color(0xFF9DCB72),
      onSurface: Color(0xFFE4F0E8),
      outline: Color(0xFF345344),
      success: Color(0xFF8DDA78),
    ),
    AppThemePreset.neutral => const AppPalette(
      background: Color(0xFF0D0F11),
      surface: Color(0xFF15171A),
      surfaceRaised: Color(0xFF1E2125),
      chrome: Color(0xFF121416),
      primary: Color(0xFFAEB7C4),
      onPrimary: Color(0xFF17191C),
      secondary: Color(0xFFF0A45D),
      tertiary: Color(0xFFD77B3F),
      onSurface: Color(0xFFE2E4E7),
      outline: Color(0xFF3A3E44),
      success: Color(0xFF8FB89B),
    ),
  };
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.chrome,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.tertiary,
    required this.onSurface,
    required this.outline,
    required this.success,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color chrome;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color tertiary;
  final Color onSurface;
  final Color outline;
  final Color success;

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? chrome,
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? tertiary,
    Color? onSurface,
    Color? outline,
    Color? success,
  }) => AppPalette(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    chrome: chrome ?? this.chrome,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    secondary: secondary ?? this.secondary,
    tertiary: tertiary ?? this.tertiary,
    onSurface: onSurface ?? this.onSurface,
    outline: outline ?? this.outline,
    success: success ?? this.success,
  );

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      chrome: Color.lerp(chrome, other.chrome, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get appPalette => Theme.of(this).extension<AppPalette>()!;
}
