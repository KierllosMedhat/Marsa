import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens and Material theme for the مرساة clinic tablet application.
///
/// Designed with a calm, warm paper-like aesthetic tailored for clinical environments,
/// with native Arabic typography (Cairo) and deep maritime colors reflecting "مرساة" (Anchor).
class AppTheme {
  static const Color backgroundWarm = Color(0xFFF8FAF6); // Calming olive paper
  static const Color primaryOlive = Color(0xFF45632D);   // Official Marsa Forest Olive Green
  static const Color primaryDark = Color(0xFF2F451E);
  static const Color primaryLight = Color(0xFF5B823D);
  static const Color accentGold = Color(0xFFB58728);     // Official Warm Ochre Gold from Logo
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFDFE5DA);
  static const Color clinicalRed = Color(0xFF922B21);
  static const Color darkCharcoal = Color(0xFF1D2619);

  // Backward compatibility aliases
  static const Color primaryNavy = primaryOlive;
  static const Color accentBlue = accentGold;

  static ThemeData get lightTheme {
    final baseTextTheme = Typography.material2021().black;
    final cairoTextTheme = GoogleFonts.cairoTextTheme(baseTextTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryOlive,
        primary: primaryOlive,
        secondary: accentGold,
        surface: backgroundWarm,
        error: clinicalRed,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundWarm,
      textTheme: cairoTextTheme,
      fontFamily: GoogleFonts.cairo().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryOlive,
        foregroundColor: Colors.white,
        elevation: 1.5,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentTextStyle: GoogleFonts.cairo(
          fontSize: 14,
          color: Colors.white,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: darkCharcoal,
        ),
        contentTextStyle: GoogleFonts.cairo(
          fontSize: 15,
          color: darkCharcoal,
        ),
      ),
    );
  }
}
