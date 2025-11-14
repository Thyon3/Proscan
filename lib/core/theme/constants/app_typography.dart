import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thyscan/core/theme/constants/theme.dart';

class AppTypography {
  // Base TextStyle with Inter font
  static TextStyle _base({
    required Color color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
  }) {
    return GoogleFonts.inter(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LIGHT MODE
  // ─────────────────────────────────────────────────────────────
  static final TextTheme light = TextTheme(
    // Headlines
    displayLarge: _base(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: AppColors.lightTextPrimary,
      height: 1.2,
    ),
    displayMedium: _base(
      color: AppColors.lightTextPrimary,
      fontSize: 45,
      fontWeight: FontWeight.bold,
    ),
    displaySmall: _base(
      color: AppColors.lightTextPrimary,
      fontSize: 36,
      fontWeight: FontWeight.bold,
    ),

    headlineLarge: _base(
      color: AppColors.lightTextPrimary,
      fontSize: 32,
      fontWeight: FontWeight.bold,
    ),
    headlineMedium: _base(
      color: AppColors.lightTextPrimary,
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
    headlineSmall: _base(
      color: AppColors.lightTextPrimary,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),

    // Titles
    titleLarge: _base(
      color: AppColors.lightTextPrimary,
      fontSize: 22,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: _base(
      color: AppColors.lightTextPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.5,
    ),
    titleSmall: _base(
      color: AppColors.lightTextSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.5,
    ),

    // Body
    bodyLarge: _base(
      color: AppColors.lightTextPrimary,
      fontSize: 16,
      height: 1.5,
    ),
    bodyMedium: _base(
      color: AppColors.lightTextSecondary,
      fontSize: 14,
      height: 1.5,
    ),
    bodySmall: _base(
      color: AppColors.lightTextSecondary,
      fontSize: 12,
      height: 1.5,
    ),

    // Labels
    labelLarge: _base(
      color: AppColors.lightTextPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: _base(
      color: AppColors.lightTextSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: _base(
      color: AppColors.lightTextSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    ),
  );

  // ─────────────────────────────────────────────────────────────
  // DARK MODE
  // ─────────────────────────────────────────────────────────────
  static final TextTheme dark = light.copyWith(
    displayLarge: light.displayLarge?.copyWith(
      color: AppColors.darkTextPrimary,
    ),
    displayMedium: light.displayMedium?.copyWith(
      color: AppColors.darkTextPrimary,
    ),
    displaySmall: light.displaySmall?.copyWith(
      color: AppColors.darkTextPrimary,
    ),
    headlineLarge: light.headlineLarge?.copyWith(
      color: AppColors.darkTextPrimary,
    ),
    headlineMedium: light.headlineMedium?.copyWith(
      color: AppColors.darkTextPrimary,
    ),
    headlineSmall: light.headlineSmall?.copyWith(
      color: AppColors.darkTextPrimary,
    ),
    titleLarge: light.titleLarge?.copyWith(color: AppColors.darkTextPrimary),
    titleMedium: light.titleMedium?.copyWith(color: AppColors.darkTextPrimary),
    titleSmall: light.titleSmall?.copyWith(color: AppColors.darkTextSecondary),
    bodyLarge: light.bodyLarge?.copyWith(color: AppColors.darkTextPrimary),
    bodyMedium: light.bodyMedium?.copyWith(color: AppColors.darkTextSecondary),
    bodySmall: light.bodySmall?.copyWith(color: AppColors.darkTextSecondary),
    labelLarge: light.labelLarge?.copyWith(color: AppColors.darkTextPrimary),
    labelMedium: light.labelMedium?.copyWith(
      color: AppColors.darkTextSecondary,
    ),
    labelSmall: light.labelSmall?.copyWith(color: AppColors.darkTextSecondary),
  );
}
