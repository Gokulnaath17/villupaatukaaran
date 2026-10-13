import 'package:flutter/material.dart';

/// Apple Music Modern Theme: Transparent Graphite Gray to Vibrant Red Accent
class AppTheme {
  AppTheme._();

  // Refined Dark Obsidian & Surface Palette (from villupaatukaaran-redesign.html)
  static const Color canvasBg = Color(0xFF101012);
  static const Color darkCanvas = Color(0xFF101012);
  static const Color windowBg = Color(0xFF101012);
  static const Color sidebarBg = Color(0xFF151517);
  static const Color dockBg = Color(0xF718181B); // rgba(24,24,27,.97)
  static const Color cardSurface = Color(0xFF1B1B1E);
  static const Color cardSurfaceElevated = Color(0xFF232327);
  static const Color cardActive = Color(0xFF232327);
  static const Color cardHover = Color(0x14FFFFFF);
  static const Color black = Color(0xFF000000);

  // Subtle 1px Hairline Borders & Dividers
  static const Color borderSubtle = Color(0x13FFFFFF); // rgba(255, 255, 255, 0.075)
  static const Color borderHighlight = Color(0x26FFFFFF); // rgba(255, 255, 255, 0.15)
  static const Color border = Color(0x13FFFFFF);

  // Signature Warm Red / Coral Accent Palette
  static const Color redAccent = Color(0xFFFA3B55);
  static const Color redAccentSoft = Color(0x24FA3B55); // rgba(250, 59, 85, 0.14)
  static const Color redGlow = Color(0x40FA3B55);
  static const Color redLight = Color(0xFFFF6579);
  static const Color redDark = Color(0xFFDF183D);

  static const LinearGradient redGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6A78), Color(0xFFDF183D)],
  );

  // Aliases for backwards compatibility
  static const Color blueAccent = redAccent;
  static const Color blueGlow = redGlow;
  static const Color blueLight = redLight;
  static const Color blueDark = redDark;
  static const LinearGradient blueGradient = redGradient;

  // Legacy aliases
  static const Color yellowAccent = redAccent;
  static const Color yellowGlow = redGlow;
  static const Color yellowLight = redLight;
  static const Color yellowDark = redDark;

  // Traffic Light & Status Indicators
  static const Color trafficRed = Color(0xFFFF5F56);
  static const Color trafficAmber = Color(0xFFFFBD2E);
  static const Color trafficGreen = Color(0xFF27C93F);

  // Album Artwork Gradient Palette
  static const Color albumYellow = Color(0xFFFFC233);
  static const Color albumCyan = Color(0xFF0099FF);
  static const Color albumLavender = Color(0xFFD9B8E6);
  static const Color albumPink = Color(0xFFFCD2D8);
  static const Color albumMint = Color(0xFFBDE4E8);

  // Typography Palette
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFFF5F4F5);
  static const Color textSecondary = Color(0xFFA09FA6);
  static const Color textMuted = Color(0xFF85848C);
  static const Color textQuiet = Color(0xFF77767E);
  static const Color textHeading = Color(0xFF8E8E93);

  // Standard Rounded Geometry
  static final BorderRadius radiusSmall = BorderRadius.circular(10);
  static final BorderRadius radiusMedium = BorderRadius.circular(13);
  static final BorderRadius radiusLarge = BorderRadius.circular(17);
  static final BorderRadius radiusXLarge = BorderRadius.circular(20);
  static final BorderRadius radiusRound = BorderRadius.circular(100);

  /// Global Modern Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: canvasBg,
      canvasColor: canvasBg,
      cardColor: cardSurface,
      dividerColor: borderSubtle,
      primaryColor: redAccent,
      colorScheme: const ColorScheme.dark(
        primary: redAccent,
        secondary: redLight,
        surface: cardSurface,
        onSurface: textPrimary,
        outline: borderSubtle,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardTheme(
        color: cardSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radiusMedium,
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      iconTheme: const IconThemeData(
        color: textPrimary,
        size: 19,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: redAccent,
        inactiveTrackColor: Color(0xFF2C2D35),
        thumbColor: textWhite,
        overlayColor: Color(0x33FA3B55),
        trackHeight: 3.0,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 4.5),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardSurfaceElevated,
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: radiusSmall,
          side: const BorderSide(color: borderHighlight, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: radiusLarge,
          side: const BorderSide(color: borderHighlight, width: 1),
        ),
      ),
    );
  }
}
