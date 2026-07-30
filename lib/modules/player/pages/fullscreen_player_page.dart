import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/theme/app_icons.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';
import 'package:stream_hub/modules/player/widgets/player_controls.dart';
import 'package:stream_hub/modules/player/widgets/gesture_detector.dart';

class FullscreenPlayerPage extends StatelessWidget {
  const FullscreenPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PlayerGestureDetector(
                  onTap: () => _toggleControls(context),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Obx(() {
                        final aspect = Get.find<PlayerController>().playbackController
                            .engine.aspectRatioRx.value;
                        return AspectRatio(
                          aspectRatio: _getAspectRatio(aspect),
                          child: Container(
                            color: Colors.black,
                            child: const Center(
                              child: Icon(
                                AppIcons.play,
                                size: 64,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        );
                      }),
                      Obx(() {
                        final state = Get.find<PlayerController>().state;
                        if (state == PlaybackState.buffering ||
                            state == PlaybackState.loading) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          );
                        }
                        if (state == PlaybackState.error) {
                          return Center(
                            child: Column(
                              children: [
                                const Icon(
                                  AppIcons.error,
                                  size: 48,
                                  color: Colors.red,
                                ),
                                AppSpacing.heightMD,
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      Get.find<PlayerController>().playbackController.retry(),
                                  icon: const Icon(AppIcons.refresh),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                    ],
                  ),
                ),
              ),
              Obx(() {
                final visible = Get.find<PlayerController>().playbackController.engine.bufferInfoRx.value != null;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: visible
                      ? PlayerControls(
                          controller: Get.find<PlayerController>(),
                          isFullscreen: true,
                        )
                      : const SizedBox.shrink(),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleControls(BuildContext context) {
    Get.find<PlayerController>().playbackController.engine.bufferInfoRx.value = null;
  }

  double _getAspectRatio(AspectRatioMode mode) {
    switch (mode) {
      case AspectRatioMode.ratio16x9:
        return 16 / 9;
      case AspectRatioMode.ratio4x3:
        return 4 / 3;
      case AspectRatioMode.original:
      case AspectRatioMode.fit:
      case AspectRatioMode.fill:
      case AspectRatioMode.stretch:
      case AspectRatioMode.zoom:
        return 16 / 9;
    }
  }
}
