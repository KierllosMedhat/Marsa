import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens and Material theme for the مرساة clinic tablet application.
///
/// Designed with a calm, warm paper-like aesthetic tailored for clinical environments,
/// with native Arabic typography (Cairo) and deep maritime colors reflecting "مرساة" (Anchor).
class AppTheme {
  static const Color backgroundWarm = Color(0xFFF5F0E8); // Warm off-white paper
  static const Color primaryNavy = Color(0xFF1B4F72); // Deep anchor navy
  static const Color accentBlue = Color(0xFF2E86AB); // Mid blue
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE8E0D5);
  static const Color clinicalRed = Color(0xFF922B21);
  static const Color darkCharcoal = Color(0xFF212121);

  static ThemeData get lightTheme {
    final baseTextTheme = Typography.material2021().black;
    final cairoTextTheme = GoogleFonts.cairoTextTheme(baseTextTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryNavy,
        primary: primaryNavy,
        secondary: accentBlue,
        surface: backgroundWarm,
        error: clinicalRed,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundWarm,
      textTheme: cairoTextTheme,
      fontFamily: GoogleFonts.cairo().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryNavy,
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
