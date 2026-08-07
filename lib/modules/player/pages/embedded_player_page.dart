import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';
import 'package:stream_hub/modules/player/widgets/player_controls.dart';

class EmbeddedPlayerPage extends GetView<PlayerController> {
  final double height;
  final bool showControls;

  const EmbeddedPlayerPage({
    super.key,
    this.height = 220.0,
    this.showControls = true,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = controller.stateRx.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildVideoLayer(),
                if (controller.sessionRx.value == null &&
                    state != PlaybackState.loading)
                  const Icon(
                    Icons.play_circle_outline,
                    size: 48,
                    color: Colors.white54,
                  ),
                if (state == PlaybackState.buffering ||
                    state == PlaybackState.loading)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                if (state == PlaybackState.error)
                  const Center(
                    child: Icon(Icons.error_outline, color: Colors.red),
                  ),
              ],
            ),
          ),
          if (showControls)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: PlayerControls(
                controller: controller,
                isFullscreen: false,
              ),
            ),
        ],
      );
    });
  }

  /// Renders the active backend's video surface. Watches [engineKindRx] so the
  /// layer swaps to the newly selected adapter (MediaKit or VLC) when the
  /// engine switches backends, and [stateRx] so the surface mounts once the
  /// adapter initializes its video controller during the load flow.
  ///
  /// Without the [stateRx] dependency the layer would lock in the adapter's
  /// pre-initialization `SizedBox.shrink()`: the engine initializes the
  /// adapter lazily inside `playMediaItem`, and on desktop the engine kind
  /// never changes (VLC is unavailable), so nothing ever rebuilt the surface
  /// and playback ran audio-only with a black frame.
  Widget _buildVideoLayer() {
    return Obx(() {
      final engine = controller.playbackController.engine;
      engine.engineKindRx.value;
      controller.stateRx.value;
      return Positioned.fill(
        child: ColoredBox(
          color: Colors.black,
          child: engine.adapter.buildPlayerWidget(),
        ),
      );
    });
  }
}
