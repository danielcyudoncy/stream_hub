import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_radius.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.darkPrimary,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkPrimary,
        onPrimary: AppColors.darkTextPrimary,
        primaryContainer: AppColors.darkPrimaryContainer,
        secondary: AppColors.darkSecondary,
        onSecondary: AppColors.darkTextPrimary,
        secondaryContainer: AppColors.darkSecondaryContainer,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        surfaceContainerHighest: AppColors.darkSurfaceVariant,
        onSurfaceVariant: AppColors.darkTextSecondary,
        error: AppColors.darkError,
        onError: AppColors.darkTextPrimary,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.getDisplay(color: AppColors.darkTextPrimary),
        headlineMedium: AppTypography.getHeadline(color: AppColors.darkTextPrimary),
        titleLarge: AppTypography.getTitle(color: AppColors.darkTextPrimary),
        bodyLarge: AppTypography.getBody(color: AppColors.darkTextPrimary),
        bodyMedium: AppTypography.getBody(color: AppColors.darkTextSecondary),
        labelLarge: AppTypography.getLabel(color: AppColors.darkTextPrimary),
        bodySmall: AppTypography.getCaption(color: AppColors.darkTextSecondary),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.lightPrimary,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightPrimary,
        onPrimary: AppColors.lightTextPrimary,
        primaryContainer: AppColors.lightPrimaryContainer,
        secondary: AppColors.lightSecondary,
        onSecondary: AppColors.lightTextPrimary,
        secondaryContainer: AppColors.lightSecondaryContainer,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        surfaceContainerHighest: AppColors.lightSurfaceVariant,
        onSurfaceVariant: AppColors.lightTextSecondary,
        error: AppColors.lightError,
        onError: AppColors.lightTextPrimary,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.getDisplay(color: AppColors.lightTextPrimary),
        headlineMedium: AppTypography.getHeadline(color: AppColors.lightTextPrimary),
        titleLarge: AppTypography.getTitle(color: AppColors.lightTextPrimary),
        bodyLarge: AppTypography.getBody(color: AppColors.lightTextPrimary),
        bodyMedium: AppTypography.getBody(color: AppColors.lightTextSecondary),
        labelLarge: AppTypography.getLabel(color: AppColors.lightTextPrimary),
        bodySmall: AppTypography.getCaption(color: AppColors.lightTextSecondary),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
