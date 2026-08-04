import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';
import 'package:stream_hub/modules/player/widgets/player_controls.dart';

class FloatingPlayerPage extends GetView<PlayerController> {
  final double width;
  final double height;
  final Offset position;
  final bool draggable;

  const FloatingPlayerPage({
    super.key,
    this.width = 320.0,
    this.height = 180.0,
    this.position = const Offset(16, 80),
    this.draggable = true,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onPanUpdate: draggable ? _onPanUpdate : null,
          onTap: () => _showExpandedControls(context),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(Icons.play_circle_outline,
                      color: Colors.white54, size: 40),
                ),
                Obx(() {
                  final state = controller.stateRx.value;
                  if (state == PlaybackState.buffering ||
                      state == PlaybackState.loading) {
                    return const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),
                Positioned(
                  top: AppSpacing.xs,
                  right: AppSpacing.xs,
                  child: IconButton(
                    onPressed: () => controller.stop(),
                    icon: const Icon(Icons.close, size: 18, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // Dragging logic handled by parent StatefulWidget
  }

  void _showExpandedControls(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, _) => Container(
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: PlayerControls(
                  controller: controller,
                  isFullscreen: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
