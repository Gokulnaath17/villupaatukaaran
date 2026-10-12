import 'package:flutter/material.dart';

/// Minimalist, boxy theme with pure black and warm golden-amber accents
class AppTheme {
  AppTheme._();

  static const Color black = Color(0xFF000000);
  static const Color darkCanvas = Color(0xFF0A0A0A);
  static const Color cardSurface = Color(0xFF121212);
  static const Color cardSurfaceElevated = Color(0xFF181818);
  static const Color border = Color(0xFF262626);
  static const Color borderHighlight = Color(0xFF404040);

  // Golden-amber palette from the base artwork
  static const Color yellowAccent = Color(0xFFFFB800);
  static const Color yellowGlow = Color(0xFFFFA000);
  static const Color yellowLight = Color(0xFFFFE082);
  static const Color yellowDark = Color(0xFFB87800);

  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFA0A0A0);
  static const Color textMuted = Color(0xFF6E6E73);

  /// Global boxy Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkCanvas,
      canvasColor: darkCanvas,
      cardColor: cardSurface,
      dividerColor: border,
      primaryColor: yellowAccent,
      colorScheme: const ColorScheme.dark(
        primary: yellowAccent,
        secondary: yellowGlow,
        surface: cardSurface,
        onSurface: textPrimary,
        outline: border,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkCanvas,
        scrolledUnderElevation: 0,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: const CardTheme(
        color: cardSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: border, width: 1),
        ),
      ),
      iconTheme: const IconThemeData(
        color: textPrimary,
        size: 20,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: yellowAccent,
        inactiveTrackColor: border,
        thumbColor: yellowAccent,
        overlayColor: Color(0x33FFB800),
        trackHeight: 3.0,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: cardSurfaceElevated,
        contentTextStyle: TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: yellowAccent, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: border, width: 1),
        ),
      ),
    );
  }
}

