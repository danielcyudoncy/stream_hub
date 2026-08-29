import 'package:flutter/widgets.dart';
import '../helpers/platform_helper.dart';

/// Screen breakpoints based on UI_GUIDELINES.md
class ResponsiveHelper {
  static const double phoneMaxWidth = 599;
  static const double tabletMaxWidth = 1023;
  static const double desktopMaxWidth = 1439;
  // Anything >= 1440 is treated as TV / large-screen.

  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width <= phoneMaxWidth;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w > phoneMaxWidth && w <= tabletMaxWidth;
  }

  static bool isDesktop(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w > tabletMaxWidth && w <= desktopMaxWidth;
  }

  static bool isTV(BuildContext context) =>
      PlatformHelper.isTV || MediaQuery.sizeOf(context).width > desktopMaxWidth;

  /// Returns a value based on the current screen size.
  static T value<T>(
    BuildContext context, {
    required T phone,
    T? tablet,
    T? desktop,
    T? tv,
  }) {
    if (isTV(context)) return tv ?? desktop ?? tablet ?? phone;
    if (isDesktop(context)) return desktop ?? tablet ?? phone;
    if (isTablet(context)) return tablet ?? phone;
    return phone;
  }
}
