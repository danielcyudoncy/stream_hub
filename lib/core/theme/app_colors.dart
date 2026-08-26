import 'package:flutter/material.dart';

class AppColors {
  // Cinematic Neon Theme Colors
  static const Color background = Color(0xFF101415);
  static const Color surface = Color(0xFF1D2022); // surface-container
  static const Color surfaceVariant = Color(0xFF323537);
  
  static const Color primary = Color(0xFFD2BBFF);
  static const Color onPrimary = Color(0xFF3F008E);
  static const Color primaryContainer = Color(0xFF7C3AED); // Neon Purple
  static const Color onPrimaryContainer = Color(0xFFEDE0FF);
  
  static const Color secondary = Color(0xFFDDFCFF); 
  static const Color onSecondary = Color(0xFF00363A);
  static const Color secondaryContainer = Color(0xFF00F1FE); // Electric Blue
  static const Color onSecondaryContainer = Color(0xFF006A70);
  
  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  
  static const Color textPrimary = Color(0xFFE0E3E5); // On-surface
  static const Color textSecondary = Color(0xFFCCC3D8); // On-surface-variant
  static const Color textMuted = Color(0xFF958DA1); // Outline

  // For backward compatibility while refactoring, mapping old names to new ones:
  static const Color darkBackground = background;
  static const Color darkSurface = surface;
  static const Color darkSurfaceVariant = surfaceVariant;
  static const Color darkPrimary = primaryContainer;
  static const Color darkSecondary = secondaryContainer;
  static const Color darkTextPrimary = textPrimary;
  static const Color darkTextSecondary = textSecondary;
  static const Color darkTextMuted = textMuted;
  static const Color darkError = error;
  static const Color darkSuccess = Color(0xFF4CAF50);
  static const Color darkWarning = Color(0xFFFFC107);

  // Light theme stubs
  static const Color lightPrimary = Color(0xFF6200EE);
  static const Color lightPrimaryContainer = Color(0xFFBB86FC);
  static const Color lightSecondary = Color(0xFF03DAC6);
  static const Color lightSecondaryContainer = Color(0xFF018786);
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF5F5F5);
  static const Color lightError = Color(0xFFB00020);
  static const Color lightTextPrimary = Color(0xFF000000);
  static const Color lightTextSecondary = Color(0xFF757575);

  // Gradients
  static const List<Color> darkBackgroundGradient = [
    Color(0xFF101415),
    Color(0xFF0B0F10),
  ];
  
  static const List<Color> primaryGradient = [
    Color(0xFF7C3AED),
    Color(0xFF00F1FE),
  ];
}
