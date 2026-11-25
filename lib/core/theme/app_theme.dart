import 'package:flutter/material.dart';

/// Core Liquid Glass design tokens and Material 3 theme builder.
class LuminaTheme {
  LuminaTheme._();

  static const Color fallbackPrimary = Color(0xFF6AE2FF);
  static const Color fallbackSecondary = Color(0xFFA87CFF);
  static const Color fallbackTertiary = Color(0xFFFF7EB6);
  static const Color surfaceBase = Color(0xFF070A12);

  static ThemeData buildTheme({ColorScheme? dynamicScheme}) {
    final scheme = dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: fallbackPrimary,
          brightness: Brightness.dark,
          primary: fallbackPrimary,
          secondary: fallbackSecondary,
          tertiary: fallbackTertiary,
          surface: surfaceBase,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.white.withValues(alpha: 0.06),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          color: Colors.white,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: Colors.white,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Color(0xFFD5DCE8),
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Color(0xFF9AA6BA),
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: scheme.primary,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
        thumbColor: Colors.white,
      ),
    );
  }
}
