import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thyscan/core/theme/constants/app_typography.dart';

class AppColors {
  // ──────────────────────── CORE BRAND COLORS ────────────────────────
  static const Color primary = Color(0xFF3DCC4B); // Same for Light & Dark
  static const Color secondary = Color(0xFF2563EB); // Rich Blue
  static const Color tertiary = Color(0xFFF5A623); // Warm Amber

  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);

  // ──────────────────────── LIGHT MODE ────────────────────────
  static const Color lightBackground = Color(0xFFF8F9FA); // Soft gray-white
  static const Color lightSurface = Color(0xFFF8FFF9); // Card / Input
  static const Color lightTextPrimary = Color(0xFF111827); // Title
  static const Color lightTextSecondary = Color(0xFF6B7280); // Hint / Label
  static const Color lightBorder = Color(0xFFE5E7EB); // Input border
  static const Color lightBottomNav = Color(0xFFFFFFFF);

  // ──────────────────────── DARK MODE ────────────────────────
  static const Color darkBackground = Color(0xFF0A0E0A); // ThyScan dark
  static const Color darkSurface = Color(0xFF1A1F1A); // Input / Card
  static const Color darkTextPrimary = Color(0xFFF9FAFB); // White
  static const Color darkTextSecondary = Color(0xFF9CA3AF); // Muted
  static const Color darkBorder = Color(0xFF2D3748);

  // // PRIMARY, SECONDARY, TERTIARY
  // static const Color primary = Color(0xFF3DCC4B); // Vibrant Green
  // static const Color secondary = Color(0xFF2563EB); // Rich Blue
  // static const Color tertiary = Color(0xFFF5A623); // Warm Amber

  // static const Color error = Color(0xFFEF4444); // Vibrant Red
  // static const Color success = Color(0xFF22C55E); // Green

  // static const Color lightBackground = Color(0xFFF9FAFB); // Soft Off-white
  // static const Color lightSurface = Color(0xFFFFFFFF); // White cards
  // static const Color lightTextPrimary = Color(0xFF111827); // Near-black
  // static const Color lightTextSecondary = Color(0xFF6B7280); // Gray
  // static const Color lightBorder = Color(0xFFE5E7EB); // Light gray
  // static const Color lightBottomNav = Color(0xFFFFFFFF);

  // // DARK MODE
  // static const Color darkPrimary = Color(0xFF34B644); // Brighter green
  // static const Color darkBackground = Color(0xFF111827);
  // static const Color darkSurface = Color(0xFF1F2937);
  // static const Color darkTextPrimary = Color(0xFFF9FAFB);
  // static const Color darkTextSecondary = Color(0xFF9CA3AF);
  // static const Color darkBorder = Color(0xFF374151);
  static const Color darkBottomNav = Color(0xFF111827);
}

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    textTheme: AppTypography.light,
    colorScheme: const ColorScheme.light().copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.tertiary,
      error: AppColors.error,
      background: AppColors.lightBackground,
      surface: AppColors.lightSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.lightSurface,
      foregroundColor: AppColors.lightTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.lightTextPrimary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        elevation: 2,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      hintStyle: TextStyle(color: AppColors.lightTextSecondary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      elevation: 2,

      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightBottomNav,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.lightTextSecondary,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
    dividerColor: AppColors.lightBorder,
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    textTheme: AppTypography.dark,
    colorScheme: const ColorScheme.dark().copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.tertiary,
      error: AppColors.error,
      background: AppColors.darkBackground,
      surface: AppColors.darkSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextPrimary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[800],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.darkBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      hintStyle: TextStyle(color: AppColors.darkTextSecondary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkBottomNav,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.darkTextSecondary,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
    dividerColor: AppColors.darkBorder,
  );
}
