import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlatformHelper {
  static bool get isWeb => kIsWeb;

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isLinux => !kIsWeb && Platform.isLinux;

  static bool get isDesktop => isMacOS || isWindows || isLinux;
  static bool get isMobile => isAndroid || isIOS;

  // Dynamic check for TV, refined during bootstrap
  static bool isTVDevice = false;

  static bool get isAppleTV => isIOS && isTVDevice;
  static bool get isAndroidTV => isAndroid && isTVDevice;
  static bool get isTV => isTVDevice || isAppleTV || isAndroidTV;

  /// Whether the platform supports 10-foot / D-Pad navigation (TV or Desktop with keyboard)
  static bool get supportsDPadNavigation => isTV || isDesktop;

  /// Auto-detects television hardware on Android and initializes [isTVDevice].
  static Future<void> initialize() async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      try {
        const channel = MethodChannel('stream_hub/native_player_launch');
        final isTv = await channel.invokeMethod<bool>('isTelevision');
        if (isTv == true) {
          isTVDevice = true;
        }
      } catch (_) {
        // Fallback: If channel is not yet ready, will remain default
      }
    }
  }
}

