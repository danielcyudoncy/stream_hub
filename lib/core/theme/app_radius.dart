import 'package:flutter/material.dart';

class AppRadius {
  static const double smallValue = 8.0;
  static const double mediumValue = 12.0;
  static const double largeValue = 16.0;
  static const double extraLargeValue = 20.0;
  static const double pillValue = 999.0;

  // BorderRadius objects
  static const BorderRadius small = BorderRadius.all(Radius.circular(smallValue));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(mediumValue));
  static const BorderRadius large = BorderRadius.all(Radius.circular(largeValue));
  static const BorderRadius extraLarge = BorderRadius.all(Radius.circular(extraLargeValue));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(pillValue));
  static const BorderRadius circular = BorderRadius.all(Radius.circular(360.0));

  // Radius objects
  static const Radius rSmall = Radius.circular(smallValue);
  static const Radius rMedium = Radius.circular(mediumValue);
  static const Radius rLarge = Radius.circular(largeValue);
  static const Radius rExtraLarge = Radius.circular(extraLargeValue);
  static const Radius rPill = Radius.circular(pillValue);
}
