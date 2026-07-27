import 'package:flutter/material.dart';

class AppTypography {
  // Base font sizes
  static const double displaySize = 36.0;
  static const double headlineSize = 24.0;
  static const double titleSize = 20.0;
  static const double bodySize = 16.0;
  static const double labelSize = 14.0;
  static const double captionSize = 12.0;
  static const double buttonSize = 15.0;
  static const double overlineSize = 10.0;

  // Custom text styles generator with scaling helper
  static TextStyle getDisplay({Color? color, double scale = 1.0}) => TextStyle(
        fontFamily: 'Inter',
        fontSize: displaySize * scale,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: color,
      );

  static TextStyle getHeadline({Color? color, double scale = 1.0}) => TextStyle(
        fontFamily: 'Inter',
        fontSize: headlineSize * scale,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle getTitle({Color? color, double scale = 1.0}) => TextStyle(
        fontFamily: 'Inter',
        fontSize: titleSize * scale,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle getBody({Color? color, double scale = 1.0}) => TextStyle(
        fontFamily: 'Inter',
        fontSize: bodySize * scale,
        fontWeight: FontWeight.normal,
        color: color,
      );

  static TextStyle getLabel({Color? color, double scale = 1.0}) => TextStyle(
        fontFamily: 'Inter',
        fontSize: labelSize * scale,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle getCaption({Color? color, double scale = 1.0}) => TextStyle(
        fontFamily: 'Inter',
        fontSize: captionSize * scale,
        fontWeight: FontWeight.normal,
        color: color,
      );

  static TextStyle getButton({Color? color, double scale = 1.0}) => TextStyle(
        fontFamily: 'Inter',
        fontSize: buttonSize * scale,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: color,
      );

  static TextStyle getOverline({Color? color, double scale = 1.0}) => TextStyle(
        fontFamily: 'Inter',
        fontSize: overlineSize * scale,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.0,
        color: color,
      );
}
