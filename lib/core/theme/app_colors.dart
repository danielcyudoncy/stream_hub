import 'package:flutter/material.dart';

class AppColors {
  // Option A: Electric Cobalt & Luminous Cyan Theme (Logo-Harmonized)
  static const Color background = Color(0xFF0A0E1A); // Deep Cinematic Midnight
  static const Color surface = Color(0xFF121829);    // Deep Slate Navy
  static const Color surfaceVariant = Color(0xFF1A2238); // Elevated Slate
  
  static const Color primary = Color(0xFF0078F8);       // Electric Cobalt Blue
  static const Color onPrimary = Color(0xFFFFFFFF);     // Pure White
  static const Color primaryContainer = Color(0xFF0052D4); // Deep Cobalt
  static const Color onPrimaryContainer = Color(0xFFE0EEFF);
  
  static const Color secondary = Color(0xFF00D0FE);     // Luminous Cyan
  static const Color onSecondary = Color(0xFF001F29);    // Dark Cyan Ink
  static const Color secondaryContainer = Color(0xFF004459); // Deep Cyan Container
  static const Color onSecondaryContainer = Color(0xFFBCEEFF);
  
  static const Color error = Color(0xFFFF5252);
  static const Color onError = Color(0xFF690005);
  
  static const Color textPrimary = Color(0xFFF8FAFC); // Ice White (On-surface)
  static const Color textSecondary = Color(0xFF94A3B8); // Cool Slate (On-surface-variant)
  static const Color textMuted = Color(0xFF64748B); // Outline / Muted

  // For backward compatibility while refactoring, mapping old names to new ones:
  static const Color darkBackground = background;
  static const Color darkSurface = surface;
  static const Color darkSurfaceVariant = surfaceVariant;
  static const Color darkPrimary = primary;
  static const Color darkSecondary = secondary;
  static const Color darkTextPrimary = textPrimary;
  static const Color darkTextSecondary = textSecondary;
  static const Color darkTextMuted = textMuted;
  static const Color darkError = error;
  static const Color darkSuccess = Color(0xFF10B981);
  static const Color darkWarning = Color(0xFFF59E0B);

  // Light theme stubs
  static const Color lightPrimary = Color(0xFF0066FE);
  static const Color lightPrimaryContainer = Color(0xFFD0E2FF);
  static const Color lightSecondary = Color(0xFF00A3C4);
  static const Color lightSecondaryContainer = Color(0xFFC0F4FF);
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9);
  static const Color lightError = Color(0xFFDC2626);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Gradients
  static const List<Color> darkBackgroundGradient = [
    Color(0xFF040812), // Deepest Midnight
    Color(0xFF0A1128), // Midnight Navy
  ];
  
  static const List<Color> primaryGradient = [
    Color(0xFF0052D4), // Deep Cobalt
    Color(0xFF0078F8), // Electric Royal Blue
    Color(0xFF00D0FE), // Luminous Cyan
  ];
}
