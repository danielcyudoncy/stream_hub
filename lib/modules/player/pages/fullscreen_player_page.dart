import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/player/native_activity_player_adapter.dart';
import 'package:stream_hub/core/theme/app_icons.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';
import 'package:stream_hub/modules/player/widgets/player_controls.dart';

class FullscreenPlayerPage extends StatefulWidget {
  const FullscreenPlayerPage({super.key});

  @override
  State<FullscreenPlayerPage> createState() => _FullscreenPlayerPageState();
}

class _FullscreenPlayerPageState extends State<FullscreenPlayerPage> {
  final PlayerController _controller = Get.find<PlayerController>();
  StreamSubscription<PlaybackState>? _stateSub;
  bool _controlsVisible = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _stateSub = _controller.playbackController.engine.stateRx.listen((state) {
      if (mounted) {
        // Rebuild so the video layer reflects the engine's active backend
        // (MediaKit or VLC) and the state overlays stay in sync.
        setState(() {});
      }
      if (state == PlaybackState.playing) {
        _autoHideControls();
      } else if (state == PlaybackState.stopped &&
          _controller.playbackController.engine.adapter
              is NativeActivityPlayerAdapter) {
        // The native player Activity closed itself (its ✕ button or the system
        // back gesture), which destroys the only place rendering the video.
        // Leave the player route so the previously opened screen is restored
        // instead of a blank black surface. `stopped` can only reach the engine
        // from this adapter's onFinished event (channel switches never stop),
        // so this can't fire spuriously.
        _handleBack();
      }
    });
    _autoHideControls();
  }

  void _autoHideControls() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controlsVisible) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _controlsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: GestureDetector(
            onTap: _toggleControls,
            child: Stack(
              children: [
                _buildVideoLayer(),
                _buildStateOverlay(),
                if (_controlsVisible) _buildControlsOverlay(context),
                _buildTopBar(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoLayer() {
    // Read the engine kind inside an Obx so a backend swap (MediaKit <-> VLC)
    // remounts the correct video surface instead of relying on a coincidental
    // state change rebuild. The widget that plays through an engine swap gets
    // replaced because Flutter matches the new adapter's keyed platform view.
    return Obx(() {
      _controller.playbackController.engine.engineKindRx.value;
      final adapter = _controller.playbackController.engine.adapter;
      return Positioned.fill(
        child: ColoredBox(
          color: Colors.black,
          child: adapter.buildPlayerWidget(),
        ),
      );
    });
  }

  Widget _buildStateOverlay() {
    return Obx(() {
      final state = _controller.playbackController.engine.stateRx.value;
      if (state == PlaybackState.loading ||
          state == PlaybackState.buffering) {
        return Positioned.fill(
          child: Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  AppSpacing.heightMD,
                  Text(
                    state == PlaybackState.loading
                        ? 'Connecting...'
                        : 'Buffering...',
                    style: AppTypography.getBody(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      if (state == PlaybackState.error) {
        final errorMessage = _controller
            .playbackController.engine.errorMessageRx.value;
        return Positioned.fill(
          child: Container(
            color: Colors.black87,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.error, size: 48, color: Colors.red),
                  AppSpacing.heightMD,
                  Text(
                    'Playback Error',
                    style: AppTypography.getTitle(color: Colors.white),
                  ),
                  AppSpacing.heightSM,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      errorMessage.isNotEmpty
                          ? errorMessage
                          : 'Unable to play this stream.',
                      style: AppTypography.getBody(color: Colors.white70),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AppSpacing.heightMD,
                  ElevatedButton.icon(
                    onPressed: () =>
                        _controller.retry(),
                    icon: const Icon(AppIcons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    });
  }

  Widget _buildControlsOverlay(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildChannelInfo(),
          PlayerControls(
            controller: _controller,
            isFullscreen: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: _controlsVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.8),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(AppIcons.back, color: Colors.white),
                onPressed: _handleBack,
              ),
              Expanded(
                child: Obx(() {
                  final title =
                      _controller.sessionRx.value?.metadata.title ?? 'Player';
                  return Text(
                    title,
                    style: AppTypography.getBody(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                }),
              ),
              Obx(() {
                final isFav = _controller.isFavoriteRx.value;
                return IconButton(
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? Colors.red : Colors.white70,
                  ),
                  onPressed: _controller.toggleFavorite,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelInfo() {
    return Obx(() {
      final item = _controller.sessionRx.value?.mediaItem;
      if (item == null) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.6),
            ],
          ),
        ),
        child: Row(
          children: [
            if (item.poster != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  item.poster!,
                  width: 32,
                  height: 32,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              AppSpacing.widthSM,
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: AppTypography.getLabel(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.subtitle != null)
                    Text(
                      item.subtitle!,
                      style: AppTypography.getCaption(color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  void _handleBack() {
    Get.back();
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    if (_controlsVisible) {
      _autoHideControls();
    } else {
      _controlsTimer?.cancel();
    }
  }
}
