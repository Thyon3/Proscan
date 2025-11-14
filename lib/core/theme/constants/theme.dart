import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class _AppColors {
  // PRIMARY, SECONDARY, TERTIARY
  static const Color primary = Color(0xFF3DCC4B); // Vibrant Green
  static const Color secondary = Color(0xFF2563EB); // Rich Blue
  static const Color tertiary = Color(0xFFF5A623); // Warm Amber

  static const Color error = Color(0xFFEF4444); // Vibrant Red
  static const Color success = Color(0xFF22C55E); // Green

  static const Color lightBackground = Color(0xFFF9FAFB); // Soft Off-white
  static const Color lightSurface = Color(0xFFFFFFFF); // White cards
  static const Color lightTextPrimary = Color(0xFF111827); // Near-black
  static const Color lightTextSecondary = Color(0xFF6B7280); // Gray
  static const Color lightBorder = Color(0xFFE5E7EB); // Light gray
  static const Color lightBottomNav = Color(0xFFFFFFFF);

  // DARK MODE
  static const Color darkPrimary = Color(0xFF34B644); // Brighter green
  static const Color darkBackground = Color(0xFF111827);
  static const Color darkSurface = Color(0xFF1F2937);
  static const Color darkTextPrimary = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkBorder = Color(0xFF374151);
  static const Color darkBottomNav = Color(0xFF111827);
}

class _AppText {
  static final TextTheme base = GoogleFonts.interTextTheme();

  static final TextTheme light = base.copyWith(
    displayLarge: base.displayLarge?.copyWith(
      fontWeight: FontWeight.bold,
      color: _AppColors.lightTextPrimary,
    ),
    displayMedium: base.displayMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: _AppColors.lightTextPrimary,
    ),
    headlineLarge: base.headlineLarge?.copyWith(
      fontWeight: FontWeight.bold,
      color: _AppColors.lightTextPrimary,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: _AppColors.lightTextPrimary,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: _AppColors.lightTextPrimary,
    ),
    bodyLarge: base.bodyLarge?.copyWith(
      height: 1.5,
      color: _AppColors.lightTextPrimary,
    ),
    bodyMedium: base.bodyMedium?.copyWith(
      height: 1.5,
      color: _AppColors.lightTextSecondary,
    ),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );

  static final TextTheme dark = light.copyWith(
    displayLarge: light.displayLarge?.copyWith(
      color: _AppColors.darkTextPrimary,
    ),
    displayMedium: light.displayMedium?.copyWith(
      color: _AppColors.darkTextPrimary,
    ),
    headlineLarge: light.headlineLarge?.copyWith(
      color: _AppColors.darkTextPrimary,
    ),
    headlineMedium: light.headlineMedium?.copyWith(
      color: _AppColors.darkTextPrimary,
    ),
    titleLarge: light.titleLarge?.copyWith(color: _AppColors.darkTextPrimary),
    bodyLarge: light.bodyLarge?.copyWith(color: _AppColors.darkTextPrimary),
    bodyMedium: light.bodyMedium?.copyWith(color: _AppColors.darkTextSecondary),
  );
}

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: _AppColors.lightBackground,
    textTheme: _AppText.light,
    colorScheme: const ColorScheme.light().copyWith(
      primary: _AppColors.primary,
      secondary: _AppColors.secondary,
      tertiary: _AppColors.tertiary,
      error: _AppColors.error,
      background: _AppColors.lightBackground,
      surface: _AppColors.lightSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: _AppColors.lightSurface,
      foregroundColor: _AppColors.lightTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: _AppColors.lightTextPrimary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _AppColors.primary,
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
        borderSide: const BorderSide(color: _AppColors.lightBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _AppColors.error, width: 2),
      ),
      hintStyle: TextStyle(color: _AppColors.lightTextSecondary),
    ),
    cardTheme: CardThemeData(
      color: _AppColors.lightSurface,
      elevation: 2,

      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: _AppColors.lightBottomNav,
      selectedItemColor: _AppColors.primary,
      unselectedItemColor: _AppColors.lightTextSecondary,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _AppColors.primary,
      foregroundColor: Colors.white,
    ),
    dividerColor: _AppColors.lightBorder,
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _AppColors.darkBackground,
    textTheme: _AppText.dark,
    colorScheme: const ColorScheme.dark().copyWith(
      primary: _AppColors.darkPrimary,
      secondary: _AppColors.secondary,
      tertiary: _AppColors.tertiary,
      error: _AppColors.error,
      background: _AppColors.darkBackground,
      surface: _AppColors.darkSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: _AppColors.darkSurface,
      foregroundColor: _AppColors.darkTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: _AppColors.darkTextPrimary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _AppColors.darkPrimary,
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
        borderSide: BorderSide(color: _AppColors.darkBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _AppColors.darkPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _AppColors.error, width: 2),
      ),
      hintStyle: TextStyle(color: _AppColors.darkTextSecondary),
    ),
    cardTheme: CardThemeData(
      color: _AppColors.darkSurface,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: _AppColors.darkBottomNav,
      selectedItemColor: _AppColors.darkPrimary,
      unselectedItemColor: _AppColors.darkTextSecondary,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _AppColors.darkPrimary,
      foregroundColor: Colors.white,
    ),
    dividerColor: _AppColors.darkBorder,
  );
}
