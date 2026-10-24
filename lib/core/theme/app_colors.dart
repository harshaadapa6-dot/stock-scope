import 'package:flutter/material.dart';

/// Central colour definitions. Gain/loss colours are always paired with signs
/// and icons in the UI so colour is never the only signal.
class AppColors {
  AppColors._();

  static const Color seed = Color(0xFF2563EB);

  static const Color navy = Color(0xFF0B1220);
  static const Color navySurface = Color(0xFF111A2E);
  static const Color navyCard = Color(0xFF16213A);
  static const Color lightBackground = Color(0xFFF3F5F9);

  // Colour-blind-friendly series palettes (Okabe-Ito inspired).
  static const List<Color> _seriesLight = [
    Color(0xFF0072B2),
    Color(0xFFC77700),
    Color(0xFF00855F),
    Color(0xFFD55E00),
    Color(0xFFAA4C8B),
  ];
  static const List<Color> _seriesDark = [
    Color(0xFF56B4E9),
    Color(0xFFF5B83D),
    Color(0xFF3DDBA8),
    Color(0xFFFF8A4C),
    Color(0xFFE7A3D1),
  ];

  static Color series(BuildContext context, int index) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final list = dark ? _seriesDark : _seriesLight;
    return list[index % list.length];
  }

  static Color positive(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF4ADE80)
          : const Color(0xFF15803D);

  static Color negative(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFF87171)
          : const Color(0xFFB91C1C);

  static Color neutral(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color forValue(BuildContext context, double? value) {
    if (value == null || !value.isFinite || value == 0) {
      return neutral(context);
    }
    return value > 0 ? positive(context) : negative(context);
  }

  static Color cardColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? navyCard
          : Colors.white;

  /// Version-independent alternative to withOpacity/withValues.
  static Color alpha(Color color, double opacity) =>
      color.withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
}
