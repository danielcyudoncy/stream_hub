import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_radius.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceVariant,
        onSurfaceVariant: AppColors.textSecondary,
        error: AppColors.error,
        onError: AppColors.onError,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.getDisplay(color: AppColors.textPrimary),
        headlineMedium: AppTypography.getHeadline(color: AppColors.textPrimary),
        titleLarge: AppTypography.getTitle(color: AppColors.textPrimary),
        bodyLarge: AppTypography.getBody(color: AppColors.textPrimary),
        bodyMedium: AppTypography.getBody(color: AppColors.textSecondary),
        labelLarge: AppTypography.getLabel(color: AppColors.textPrimary),
        bodySmall: AppTypography.getCaption(color: AppColors.textSecondary),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
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
