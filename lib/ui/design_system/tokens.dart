import 'package:flutter/material.dart';

/// Design tokens (section 57). Nothing in the UI should use a raw color,
/// spacing or radius literal — everything routes through here so the
/// "ancient world + modern mobile game" identity stays consistent.
class ReinosColors {
  static const Color background = Color(0xFF0E0B08);
  static const Color surface = Color(0xFF1C1712);
  static const Color parchment = Color(0xFFE8D9B5);
  static const Color bronze = Color(0xFF8C6239);
  static const Color gold = Color(0xFFC9A227);
  static const Color accent = Color(0xFFB2543A);
  static const Color danger = Color(0xFFA23B2E);
  static const Color success = Color(0xFF3E7A4C);
  static const Color warning = Color(0xFFCC9A2E);

  static const List<Color> playerColors = [
    Color(0xFF3B6EA5), // blue
    Color(0xFFA23B2E), // red
    Color(0xFF3E7A4C), // green
    Color(0xFFCC9A2E), // yellow
    Color(0xFF6E4A8C), // purple
    Color(0xFFE8E2D6), // white
  ];
}

class ReinosSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 40;
}

class ReinosRadius {
  static const double sm = 6;
  static const double md = 12;
  static const double lg = 20;
}

class ReinosDuration {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 600);
}

class ReinosTypography {
  static const String displayFontFamily = 'serif';

  static const TextStyle title = TextStyle(
    fontFamily: displayFontFamily,
    fontSize: 40,
    fontWeight: FontWeight.bold,
    color: ReinosColors.gold,
    letterSpacing: 4,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 14,
    color: ReinosColors.parchment,
    letterSpacing: 2,
  );

  static const TextStyle heading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: ReinosColors.parchment,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: ReinosColors.parchment,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    color: ReinosColors.parchment,
    letterSpacing: 1,
  );
}

ThemeData buildReinosTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: ReinosColors.background,
    colorScheme: ColorScheme.dark(
      primary: ReinosColors.gold,
      secondary: ReinosColors.bronze,
      surface: ReinosColors.surface,
      error: ReinosColors.danger,
    ),
    textTheme: const TextTheme(
      headlineLarge: ReinosTypography.title,
      titleMedium: ReinosTypography.heading,
      bodyMedium: ReinosTypography.body,
      labelSmall: ReinosTypography.label,
    ),
  );
}
