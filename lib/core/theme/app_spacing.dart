import 'package:flutter/material.dart';

class AppSpacing {
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Horizontal SizedBox constants
  static const SizedBox widthXXS = SizedBox(width: xxs);
  static const SizedBox widthXS = SizedBox(width: xs);
  static const SizedBox widthSM = SizedBox(width: sm);
  static const SizedBox widthMD = SizedBox(width: md);
  static const SizedBox widthLG = SizedBox(width: lg);
  static const SizedBox widthXL = SizedBox(width: xl);
  static const SizedBox widthXXL = SizedBox(width: xxl);

  // Vertical SizedBox constants
  static const SizedBox heightXXS = SizedBox(height: xxs);
  static const SizedBox heightXS = SizedBox(height: xs);
  static const SizedBox heightSM = SizedBox(height: sm);
  static const SizedBox heightMD = SizedBox(height: md);
  static const SizedBox heightLG = SizedBox(height: lg);
  static const SizedBox heightXL = SizedBox(height: xl);
  static const SizedBox heightXXL = SizedBox(height: xxl);

  // Padding helpers
  static const EdgeInsets paddingAllXS = EdgeInsets.all(xs);
  static const EdgeInsets paddingAllSM = EdgeInsets.all(sm);
  static const EdgeInsets paddingAllMD = EdgeInsets.all(md);
  static const EdgeInsets paddingAllLG = EdgeInsets.all(lg);
  
  static const EdgeInsets paddingHorizontalMD = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingVerticalMD = EdgeInsets.symmetric(vertical: md);
}
