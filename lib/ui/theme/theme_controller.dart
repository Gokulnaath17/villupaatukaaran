import 'package:flutter/material.dart';

/// Apple Music Modern Theme: Transparent Graphite Gray to Vibrant Red Accent
class AppTheme {
  AppTheme._();

  // Translucent Gray Canvas & Window Surfaces (Apple Music Obsidian/Gray Glass)
  static const Color canvasBg = Color(0xFF141416);
  static const Color darkCanvas = Color(0xFF141416);
  static const Color windowBg = Color(0xE61C1C1E); // 90% translucent dark graphite
  static const Color sidebarBg = Color(0xF218181A); // 95% translucent dark sidebar
  static const Color dockBg = Color(0xF518181A); // Persistent bottom player dock
  static const Color cardSurface = Color(0x8028282B); // 50% translucent smoky gray glass
  static const Color cardSurfaceElevated = Color(0xBF323236);
  static const Color cardActive = Color(0xFF323236); // Active playing card highlight
  static const Color cardHover = Color(0x993A3A3E);
  static const Color black = Color(0xFF000000);

  // Borders & Dividers
  static const Color borderSubtle = Color(0x1AFFFFFF); // 10% translucent white
  static const Color borderHighlight = Color(0x33FFFFFF); // 20% translucent white
  static const Color border = Color(0x1AFFFFFF);

  // Signature Apple Music Vibrant Red Accent Palette
  static const Color redAccent = Color(0xFFFA243C); // Apple Music Red
  static const Color redGlow = Color(0x66FA243C);
  static const Color redLight = Color(0xFFFF4D63);
  static const Color redDark = Color(0xFFD6132A);

  static const LinearGradient redGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF334B), Color(0xFFE0102A)],
  );

  // Aliases for seamless backwards compatibility across existing widgets
  static const Color blueAccent = redAccent;
  static const Color blueGlow = redGlow;
  static const Color blueLight = redLight;
  static const Color blueDark = redDark;
  static const LinearGradient blueGradient = redGradient;

  // Legacy alias for smooth backwards compatibility
  static const Color yellowAccent = redAccent;
  static const Color yellowGlow = redGlow;
  static const Color yellowLight = redLight;
  static const Color yellowDark = redDark;

  // macOS Traffic Light Dots
  static const Color trafficRed = Color(0xFFFF5F56);
  static const Color trafficAmber = Color(0xFFFFBD2E);
  static const Color trafficGreen = Color(0xFF27C93F);

  // 5 Album Carousel Card Colors (matching mod.png)
  static const Color albumYellow = Color(0xFFFFC233);
  static const Color albumCyan = Color(0xFF0099FF);
  static const Color albumLavender = Color(0xFFD9B8E6);
  static const Color albumPink = Color(0xFFFCD2D8);
  static const Color albumMint = Color(0xFFBDE4E8);

  // Apple SF Typography Colors
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA1A1A6); // Apple SF secondary text
  static const Color textMuted = Color(0xFF6E6E73); // Apple SF tertiary text
  static const Color textHeading = Color(0xFF8E8E93);

  // Standard Rounded Geometry
  static final BorderRadius radiusSmall = BorderRadius.circular(10);
  static final BorderRadius radiusMedium = BorderRadius.circular(14);
  static final BorderRadius radiusLarge = BorderRadius.circular(18);
  static final BorderRadius radiusXLarge = BorderRadius.circular(22);

  /// Global Modern Translucent Dark Theme
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
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
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
        size: 20,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: redAccent,
        inactiveTrackColor: Color(0xFF38383A),
        thumbColor: textWhite,
        overlayColor: Color(0x33FA243C),
        trackHeight: 3.0,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardSurfaceElevated,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: radiusSmall,
          side: const BorderSide(color: redAccent, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sidebarBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: windowBg,
        shape: RoundedRectangleBorder(
          borderRadius: radiusLarge,
          side: const BorderSide(color: borderHighlight, width: 1),
        ),
      ),
    );
  }
}
