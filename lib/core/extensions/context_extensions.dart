import 'package:flutter/material.dart';

extension ContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => theme.colorScheme;
  TextTheme get typography => theme.textTheme;

  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  // Responsive device type queries
  bool get isPhone => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1024;
  bool get isDesktop => screenWidth >= 1024 && screenWidth < 1440;
  bool get isTV => screenWidth >= 1440;

  // Spacing layout helpers
  EdgeInsets get paddingAll => EdgeInsets.all(screenWidth < 600 ? 12.0 : 16.0);
}
