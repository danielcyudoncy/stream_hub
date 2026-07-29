import 'package:flutter/material.dart';

class AppColors {
  // Dark Theme Colors (Primary style for StreamHub Pro - premium dark look)
  static const Color darkPrimary = Color(0xFF6366F1); // Indigo
  static const Color darkPrimaryContainer = Color(0xFF312E81);
  static const Color darkSecondary = Color(0xFF14B8A6); // Teal
  static const Color darkSecondaryContainer = Color(0xFF115E59);
  static const Color darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color darkSurface = Color(0xFF1E293B); // Slate 800
  static const Color darkSurfaceVariant = Color(0xFF334155); // Slate 700
  static const Color darkError = Color(0xFFEF4444); // Red
  static const Color darkSuccess = Color(0xFF10B981); // Green
  static const Color darkWarning = Color(0xFFF59E0B); // Amber

  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color darkTextMuted = Color(0xFF64748B); // Slate 500

  // Light Theme Colors
  static const Color lightPrimary = Color(0xFF4F46E5); // Indigo Darker
  static const Color lightPrimaryContainer = Color(0xFFEEF2FF);
  static const Color lightSecondary = Color(0xFF0D9488); // Teal Darker
  static const Color lightSecondaryContainer = Color(0xFFCCFBF1);
  static const Color lightBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9); // Slate 100
  static const Color lightError = Color(0xFFDC2626);
  static const Color lightSuccess = Color(0xFF16A34A);
  static const Color lightWarning = Color(0xFFD97706);

  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate 900
  static const Color lightTextSecondary = Color(0xFF475569); // Slate 600
  static const Color lightTextMuted = Color(0xFF94A3B8); // Slate 400

  // Gradients
  static const List<Color> darkBackgroundGradient = [
    Color(0xFF0F172A),
    Color(0xFF020617),
  ];
  static const List<Color> lightBackgroundGradient = [
    Color(0xFFF8FAFC),
    Color(0xFFE2E8F0),
  ];
  static const List<Color> primaryGradient = [
    Color(0xFF6366F1),
    Color(0xFF4F46E5),
  ];
  static const List<Color> secondaryGradient = [
    Color(0xFF14B8A6),
    Color(0xFF0D9488),
  ];
}
