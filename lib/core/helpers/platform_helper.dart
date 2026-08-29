import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformHelper {
  static bool get isWeb => kIsWeb;

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isLinux => !kIsWeb && Platform.isLinux;

  static bool get isDesktop => isMacOS || isWindows || isLinux;
  static bool get isMobile => isAndroid || isIOS;

  // Dynamic check for TV, which can be refined during bootstrap using device_info
  static bool isTVDevice = false;

  static bool get isAppleTV => isIOS && isTVDevice;
  static bool get isAndroidTV => isAndroid && isTVDevice;
  static bool get isTV => isTVDevice || isAppleTV || isAndroidTV;

  /// Whether the platform supports 10-foot / D-Pad navigation (TV or Desktop with keyboard)
  static bool get supportsDPadNavigation => isTV || isDesktop;
}
