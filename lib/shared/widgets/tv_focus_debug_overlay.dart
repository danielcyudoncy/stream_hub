import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/services/tv_navigation_service.dart';

/// Developer-only non-intrusive HUD overlay displaying TV focus diagnostics
/// when [TvNavigationService.debugMode] is active.
class TvFocusDebugOverlay extends StatelessWidget {
  const TvFocusDebugOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<TvNavigationService>()) {
      return const Positioned(
        top: 0,
        right: 0,
        child: SizedBox.shrink(),
      );
    }

    final nav = Get.find<TvNavigationService>();

    return Obx(() {
      if (!nav.debugMode.value) {
        return const Positioned(
          top: 0,
          right: 0,
          child: SizedBox.shrink(),
        );
      }

      final region = nav.currentRegionId.value;
      final item = nav.currentItemId.value;
      final keyEvent = nav.lastKeyEvent.value;

      return Positioned(
        top: 16.0,
        right: 16.0,
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.greenAccent, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 8.0,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tv, size: 14, color: Colors.greenAccent),
                    SizedBox(width: 6),
                    Text(
                      'TV NAV HUD',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Region: ${region.isEmpty ? "NONE" : region}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  'Item: ${item.isEmpty ? "NONE" : item}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
                if (keyEvent.isNotEmpty)
                  Text(
                    'Key: $keyEvent',
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
