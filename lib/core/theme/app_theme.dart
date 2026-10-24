import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Material 3 light and dark themes.
///
/// Component themes whose class names changed across Flutter releases
/// (CardTheme, DialogTheme, TabBarTheme, InputDecorationTheme) are
/// intentionally not used, so the project compiles on a range of SDKs.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    ).copyWith(
      surface: isDark ? AppColors.navySurface : Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );

    return base.copyWith(
      scaffoldBackgroundColor:
          isDark ? AppColors.navy : AppColors.lightBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.navy : AppColors.lightBackground,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.navySurface : Colors.white,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? AppColors.navySurface : Colors.white,
        indicatorColor: scheme.primaryContainer,
      ),
      textTheme: base.textTheme.copyWith(
        headlineMedium:
            base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        titleLarge:
            base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium:
            base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      dividerColor: scheme.outlineVariant,
    );
  }
}
