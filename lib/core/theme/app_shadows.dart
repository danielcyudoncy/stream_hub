import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppShadows {
  static const BoxShadow small = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 4.0,
    offset: Offset(0, 2),
  );

  static const BoxShadow medium = BoxShadow(
    color: Color(0x12000000),
    blurRadius: 8.0,
    offset: Offset(0, 4),
  );

  static const BoxShadow large = BoxShadow(
    color: Color(0x18000000),
    blurRadius: 16.0,
    offset: Offset(0, 8),
  );

  static const BoxShadow dialog = BoxShadow(
    color: Color(0x24000000),
    blurRadius: 24.0,
    offset: Offset(0, 10),
  );

  static const BoxShadow card = BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 12.0,
    offset: Offset(0, 4),
  );

  static BoxShadow get neonFocusGlow => BoxShadow(
        color: AppColors.primary.withValues(alpha: 0.6),
        blurRadius: 20.0,
        spreadRadius: 2.0,
      );

  static List<BoxShadow> get smallList => [small];
  static List<BoxShadow> get mediumList => [medium];
  static List<BoxShadow> get largeList => [large];
  static List<BoxShadow> get dialogList => [dialog];
  static List<BoxShadow> get cardList => [card];
}
