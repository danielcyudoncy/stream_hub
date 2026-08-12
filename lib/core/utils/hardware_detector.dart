import 'dart:io';
import 'package:flutter/services.dart';

class HardwareDetector {
  static const MethodChannel _channel = MethodChannel('stream_hub/native_player_launch');

  static bool? _isUnisocOrMaliCached;

  static Future<bool> isUnisocOrMali() async {
    if (_isUnisocOrMaliCached != null) {
      return _isUnisocOrMaliCached!;
    }

    if (!Platform.isAndroid) {
      _isUnisocOrMaliCached = false;
      return false;
    }

    try {
      final info = await _channel.invokeMapMethod<String, dynamic>('getDeviceHardwareInfo');
      if (info != null) {
        final hardware = (info['hardware'] as String? ?? '').toLowerCase();
        final board = (info['board'] as String? ?? '').toLowerCase();
        final manufacturer = (info['manufacturer'] as String? ?? '').toLowerCase();
        final model = (info['model'] as String? ?? '').toLowerCase();
        final brand = (info['brand'] as String? ?? '').toLowerCase();

        // Unisoc reports its SoCs under several naming schemes. Hardware/board
        // for modern chips is the internal UMS part number (itel C671L =
        // UMS9230, i.e. Tiger T606); older parts are Spreadtrum "SP"/"SC" and
        // "sprd"/"spd" strings. Without this, `ums9230` hardware is missed and
        // VOD stays on MediaKit, which black-screens on this device class.
        final isUnisoc = hardware.contains('unisoc') ||
            hardware.contains('sp98') ||
            hardware.contains('sc98') ||
            hardware.contains('ums') ||
            hardware.contains('sprd') ||
            hardware.contains('spd') ||
            board.contains('unisoc') ||
            board.contains('sp98') ||
            board.contains('sc98') ||
            board.contains('ums') ||
            board.contains('sprd') ||
            board.contains('spd') ||
            model.contains('unisoc') ||
            brand.contains('unisoc') ||
            manufacturer.contains('unisoc');

        final isMaliPair = hardware.contains('mt6') || 
            hardware.contains('mt8') ||
            board.contains('universal') || 
            board.contains('exynos');

        if (isUnisoc || isMaliPair) {
          _isUnisocOrMaliCached = true;
          return true;
        }
      }
    } catch (_) {
      // Fallback
    }

    _isUnisocOrMaliCached = false;
    return false;
  }
}
