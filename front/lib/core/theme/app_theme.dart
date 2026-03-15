import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Application theme configuration - PLANTO theme
class AppTheme {
  AppTheme._();

  // ──────────────── Light colors ────────────────
  static const Color primaryColor = Color(0xFF4A6741);
  static const Color secondaryColor = Color(0xFF6B8E63);
  static const Color accentColor = Color(0xFF8FBC8F);
  static const Color backgroundColor = Color(0xFFCCD5C8);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color errorColor = Color(0xFFE74C3C);
  static const Color successColor = Color(0xFF27AE60);
  static const Color textPrimary = Color(0xFF2C3E2D);
  static const Color textSecondary = Color(0xFF6B7B6C);

  // ──────────────── Dark colors ────────────────
  static const Color darkBackgroundColor = Color(0xFF1A2F1A);
  static const Color darkSurfaceColor = Color(0xFF2D4A2D);
  static const Color darkCardColor = Color(0xFF253D25);
  static const Color darkInputFill = Color(0xFF3A5A3A);
  static const Color darkTextPrimary = Color(0xFFE8EDE8);
  static const Color darkTextSecondary = Color(0xFFA8B8A8);
  static const Color darkDivider = Color(0xFF3E5E3E);
  static const Color darkBorder = Color(0xFF4A6A4A);

  // ──────────────── Context-aware helpers ────────────────
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Scaffold / page background
  static Color scaffoldBg(BuildContext context) =>
      isDark(context) ? darkBackgroundColor : backgroundColor;

  /// Card / elevated surface background
  static Color cardBg(BuildContext context) =>
      isDark(context) ? darkCardColor : surfaceColor;

  /// Input field fill color
  static Color inputFill(BuildContext context) =>
      isDark(context) ? darkInputFill : const Color(0xFFF8F9FA);

  /// Light grey background (0xFFF5F5F5 in light, darker in dark)
  static Color lightBg(BuildContext context) =>
      isDark(context) ? darkSurfaceColor : const Color(0xFFF5F5F5);

  /// Primary text color
  static Color textPrimaryC(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;

  /// Secondary / hint text color
  static Color textSecondaryC(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  /// Grey text (replaces Colors.grey.shade600/700)
  static Color textGrey(BuildContext context) =>
      isDark(context) ? Colors.grey.shade400 : Colors.grey.shade600;

  /// Darker grey text (replaces Colors.grey.shade700)
  static Color textGreyDark(BuildContext context) =>
      isDark(context) ? Colors.grey.shade300 : Colors.grey.shade700;

  /// Divider / separator color
  static Color divider(BuildContext context) =>
      isDark(context) ? darkDivider : Colors.grey.shade300;

  /// Border color
  static Color border(BuildContext context) =>
      isDark(context) ? darkBorder : Colors.grey.shade300;

  /// Light border (replaces Colors.grey.shade200)
  static Color borderLight(BuildContext context) =>
      isDark(context) ? darkDivider : Colors.grey.shade200;

  /// Shadow color
  static Color shadow(BuildContext context) =>
      isDark(context) ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.1);

  /// Soft shadow (replaces Colors.black.withOpacity(0.05))
  static Color shadowSoft(BuildContext context) =>
      isDark(context) ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.05);

  /// White foreground (text on primary, icons on dark bg)
  static Color onPrimary(BuildContext context) => Colors.white;

  /// Chip / tag background
  static Color chipBg(BuildContext context) =>
      isDark(context) ? darkInputFill : const Color(0xFFF0F4EF);

  /// Error light background (replaces Colors.red.shade50)
  static Color errorBgLight(BuildContext context) =>
      isDark(context) ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50;

  /// Error border (replaces Colors.red.shade200)
  static Color errorBorder(BuildContext context) =>
      isDark(context) ? Colors.red.shade700 : Colors.red.shade200;

  /// Error text (replaces Colors.red.shade700)
  static Color errorText(BuildContext context) =>
      isDark(context) ? Colors.red.shade300 : Colors.red.shade700;

  /// Overlay white (replaces Colors.white.withOpacity)
  static Color overlayWhite(BuildContext context, double opacity) =>
      isDark(context)
          ? Colors.white.withOpacity(opacity * 0.5)
          : Colors.white.withOpacity(opacity);

  // ──────────────── Themes ────────────────

  /// Light theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: errorColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      textTheme: GoogleFonts.poppinsTextTheme(),
      dividerColor: Colors.grey.shade300,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: Colors.grey.shade300),
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(16),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 8,
        shadowColor: Colors.black26,
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: GoogleFonts.poppins(
          color: textSecondary,
          fontSize: 14,
        ),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
      ),
    );
  }

  /// Dark theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: accentColor,
        secondary: secondaryColor,
        surface: darkSurfaceColor,
        error: errorColor,
      ),
      scaffoldBackgroundColor: darkBackgroundColor,
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      dividerColor: darkDivider,
      cardTheme: CardThemeData(
        elevation: 4,
        color: darkCardColor,
        shadowColor: Colors.black45,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: darkTextPrimary,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: darkBackgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTextPrimary,
          side: BorderSide(color: darkBorder),
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: accentColor, width: 2),
        ),
        hintStyle: GoogleFonts.poppins(
          color: darkTextSecondary,
          fontSize: 14,
        ),
        prefixIconColor: darkTextSecondary,
        suffixIconColor: darkTextSecondary,
      ),
    );
  }
}
