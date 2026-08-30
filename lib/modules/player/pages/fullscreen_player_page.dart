import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:floating/floating.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/media/player/native_activity_player_adapter.dart';
import 'package:stream_hub/core/theme/app_icons.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';
import 'package:stream_hub/core/media/player/ijk_player_adapter.dart';
import 'package:stream_hub/modules/player/widgets/keyboard_shortcuts.dart';
import 'package:stream_hub/modules/player/widgets/player_controls.dart';
import 'package:stream_hub/modules/player/widgets/next_episode_overlay.dart';
import 'package:stream_hub/modules/player/widgets/skip_intro_button.dart';
import 'package:stream_hub/modules/player/widgets/player_touch_gesture_overlay.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

class FullscreenPlayerPage extends StatefulWidget {
  const FullscreenPlayerPage({super.key});

  @override
  State<FullscreenPlayerPage> createState() => _FullscreenPlayerPageState();
}

class _FullscreenPlayerPageState extends State<FullscreenPlayerPage> {
  final PlayerController _controller = Get.find<PlayerController>();
  Floating? _floating;
  StreamSubscription<PlaybackState>? _stateSub;
  bool _controlsVisible = true;
  Timer? _controlsTimer;

  /// PiP is only supported on Android via the `floating` package.
  static bool get _isPiPSupported => Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    if (_isPiPSupported) {
      _floating = Floating();
    }
    _setupPlayer();
  }

  void _setupPlayer() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _stateSub = _controller.playbackController.engine.stateRx.listen((state) {
      // NOTE: Do NOT call setState() here. The Obx widgets in the tree
      // already reactively rebuild for state/engine changes. A full
      // StatefulWidget rebuild can destabilize the MediaKit Video surface
      // causing the video to vanish while audio continues.
      if (state == PlaybackState.playing) {
        _autoHideControls();
      } else if (state == PlaybackState.stopped &&
          (_controller.playbackController.engine.adapter
                  is NativeActivityPlayerAdapter ||
              _controller.playbackController.engine.adapter
                  is IjkPlayerAdapter)) {
        // The native Activity finished (e.g. user pressed back on the TV remote
        // inside the native player UI). Pop the fullscreen page so the app
        // returns to the previous screen.
        _stateSub?.cancel();
        _stateSub = null;
        Get.back();
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
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Widget _buildInteractivePlayer() {
    return PlayerKeyboardShortcuts(
      onPlayPause: () {
        if (!_controlsVisible) {
          setState(() => _controlsVisible = true);
          _autoHideControls();
        } else {
          _controller.togglePlayPause();
        }
      },
      onStop: _handleBack,
      onSeekForward: () {
        final newPos = _controller.position + const Duration(seconds: 10);
        _controller.seek(newPos);
        if (!_controlsVisible) {
          setState(() => _controlsVisible = true);
          _autoHideControls();
        }
      },
      onSeekBackward: () {
        final newPos = _controller.position - const Duration(seconds: 10);
        _controller.seek(newPos);
        if (!_controlsVisible) {
          setState(() => _controlsVisible = true);
          _autoHideControls();
        }
      },
      onChannelUp: () => _controller.next(),
      onChannelDown: () => _controller.previous(),
      onDpadPress: () {
        if (!_controlsVisible) {
          setState(() => _controlsVisible = true);
          _autoHideControls();
        }
      },
      child: PlayerTouchGestureOverlay(
        onTap: _toggleControls,
        onVolumeChanged: (vol) => _controller.setVolume(vol),
        controls: Stack(
          children: [
            _buildStateOverlay(),
            _buildSkipIntroOverlay(),
            _buildNextEpisodeOverlay(),
            if (_controlsVisible) ...[
              _buildControlsOverlay(context),
              _buildTopBar(context),
            ],
          ],
        ),
        child: _buildVideoLayer(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExternal =
        _controller.playbackController.engine.adapter
            is NativeActivityPlayerAdapter ||
        _controller.playbackController.engine.adapter is IjkPlayerAdapter;

    if (isExternal) {
      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          _stateSub?.cancel();
          _stateSub = null;
          _controlsTimer?.cancel();
        },
        child: const Scaffold(
          backgroundColor: Colors.black,
          body: SizedBox.shrink(),
        ),
      );
    }

    if (!_isPiPSupported) {
      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          _stateSub?.cancel();
          _stateSub = null;
          _controlsTimer?.cancel();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _buildInteractivePlayer(),
        ),
      );
    }

    return PiPSwitcher(
      floating: _floating!,
      childWhenEnabled: Scaffold(
        backgroundColor: Colors.black,
        body: _buildVideoLayer(),
      ),
      childWhenDisabled: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          _stateSub?.cancel();
          _stateSub = null;
          _controlsTimer?.cancel();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _buildInteractivePlayer(),
        ),
      ),
    );
  }

  Widget _buildSkipIntroOverlay() {
    return Obx(() {
      if (_controller.showSkipIntroRx.value) {
        return SkipIntroButton(onSkip: _controller.skipIntro);
      }
      return const SizedBox.shrink();
    });
  }

  Widget _buildNextEpisodeOverlay() {
    return Obx(() {
      final show = _controller.showNextEpisodeOverlayRx.value;
      final nextEp = _controller.nextEpisodeRx.value;
      if (show && nextEp != null) {
        return NextEpisodeOverlay(
          nextEpisode: nextEp,
          onPlayNow: _controller.playNextEpisode,
          onCancel: _controller.cancelNextEpisodeCountdown,
        );
      }
      return const SizedBox.shrink();
    });
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
      if (state == PlaybackState.loading || state == PlaybackState.buffering) {
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
        final errorMessage =
            _controller.playbackController.engine.errorMessageRx.value;
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
                  TvFocusable(
                    onTap: () => _controller.retry(),
                    scale: 1.08,
                    borderRadius: BorderRadius.circular(12),
                    child: ElevatedButton.icon(
                      onPressed: () => _controller.retry(),
                      icon: const Icon(AppIcons.refresh),
                      label: const Text('Retry'),
                    ),
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
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildChannelInfo(),
            PlayerControls(
              controller: _controller,
              isFullscreen: true,
              onPiPPressed: _isPiPSupported && _floating != null
                  ? () => _floating!.enable(ImmediatePiP())
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                TvFocusable(
                  onTap: _handleBack,
                  scale: 1.15,
                  borderRadius: BorderRadius.circular(24),
                  child: IconButton(
                    icon: const Icon(AppIcons.back, color: Colors.white),
                    onPressed: _handleBack,
                  ),
                ),
                Expanded(
                  child: Obx(() {
                    final title =
                        _controller.sessionRx.value?.metadata.title ?? 'Player';
                    return Text(
                      title,
                      style: AppTypography.getBody(
                        color: Colors.white,
                      ).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    );
                  }),
                ),
                Obx(() {
                  final isFav = _controller.isFavoriteRx.value;
                  return TvFocusable(
                    onTap: _controller.toggleFavorite,
                    scale: 1.15,
                    borderRadius: BorderRadius.circular(24),
                    child: IconButton(
                      icon: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? Colors.red : Colors.white70,
                      ),
                      onPressed: _controller.toggleFavorite,
                    ),
                  );
                }),
              ],
            ),
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
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
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
