// modules/live_tv/widgets/live_tv_embedded_player.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/media/enums/aspect_ratio_mode.dart';
import '../../../core/media/enums/playback_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../../../core/utils/title_formatter.dart';
import '../../../data/models/channel.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/channel_placeholder.dart';
import '../../../shared/widgets/keep_screen_on.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../../../shared/widgets/tv_player_keyboard_hint.dart';
import '../../player/controllers/player_controller.dart';
import '../../player/widgets/audio_track_selector.dart';
import '../../player/widgets/subtitle_selector.dart' hide AudioTrackSelector;
import '../../player/widgets/player_touch_gesture_overlay.dart';
import '../controllers/live_tv_controller.dart';

class LiveTvEmbeddedPlayer extends StatefulWidget {
  final LiveTVController controller;
  final bool isFullscreen;
  final bool autofocus;
  final VoidCallback? onMoveDown;
  final VoidCallback? onMoveUp;

  const LiveTvEmbeddedPlayer({
    super.key,
    required this.controller,
    this.isFullscreen = false,
    this.autofocus = true,
    this.onMoveDown,
    this.onMoveUp,
  });

  @override
  State<LiveTvEmbeddedPlayer> createState() => LiveTvEmbeddedPlayerState();
}

class LiveTvEmbeddedPlayerState extends State<LiveTvEmbeddedPlayer> {
  bool _controlsVisible = true;
  Timer? _controlsTimer;
  bool _quickZapperOpen = false;
  String? _hudToastText;
  Timer? _hudToastTimer;
  final FocusNode _playPauseFocusNode = FocusNode(
    debugLabel: 'LiveTvPlayPause',
  );
  final FocusNode _bottomPlayPauseFocusNode = FocusNode(
    debugLabel: 'LiveTvBottomPlayPause',
  );
  final FocusNode _stopFocusNode = FocusNode(
    debugLabel: 'LiveTvStop',
  );
  final FocusNode _favoriteFocusNode = FocusNode(
    debugLabel: 'LiveTvFavorite',
  );
  final FocusNode _aspectRatioFocusNode = FocusNode(
    debugLabel: 'LiveTvAspectRatio',
  );
  final FocusNode _audioFocusNode = FocusNode(
    debugLabel: 'LiveTvAudio',
  );
  final FocusNode _subtitleFocusNode = FocusNode(
    debugLabel: 'LiveTvSubtitle',
  );
  final FocusNode _quickZapperFocusNode = FocusNode(
    debugLabel: 'LiveTvQuickZapper',
  );
  final FocusNode _fullscreenFocusNode = FocusNode(
    debugLabel: 'LiveTvFullscreen',
  );

  @visibleForTesting
  FocusNode get playPauseFocusNode => _playPauseFocusNode;

  /// Persistent focus anchor that stays available even when controls
  /// are auto-hidden. Serves as the player's D-pad re-entry point and
  /// fallback when [_playPauseFocusNode] cannot receive focus.
  final FocusNode _playerAnchorFocusNode = FocusNode(
    debugLabel: 'LiveTvPlayerAnchor',
  );

  KeyEventResult _handleBottomControlKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
          widget.onMoveDown != null) {
        widget.onMoveDown!();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_playPauseFocusNode.canRequestFocus) {
          _playPauseFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  /// Wakes up the player controls and focuses the primary action (Play/Pause).
  void focusPlayer() {
    _showControlsTemporarily();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_playPauseFocusNode.canRequestFocus) {
        _playPauseFocusNode.requestFocus();
      } else if (_playerAnchorFocusNode.canRequestFocus) {
        _playerAnchorFocusNode.requestFocus();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _startControlsTimer();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_playPauseFocusNode.canRequestFocus) {
          _playPauseFocusNode.requestFocus();
        } else if (_playerAnchorFocusNode.canRequestFocus) {
          _playerAnchorFocusNode.requestFocus();
        }
      });
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    final seconds = widget.isFullscreen ? 5 : 8;
    _controlsTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted || !_controlsVisible) return;
      final ctrl = widget.controller.inlinePlayerController;
      final state = ctrl?.playbackController.engine.stateRx.value;
      // Keep controls on screen while paused; hiding them hides the resume button.
      if (state == PlaybackState.paused) return;
      setState(() => _controlsVisible = false);
    });
  }

  void _focusPlayPauseIfControlsVisible() {
    if (_controlsVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controlsVisible) return;

        // 1. If no focus is held anywhere, target the play/pause node.
        final current = FocusManager.instance.primaryFocus;
        if (current == null || !current.hasFocus) {
          _requestFocusOrFallback(_playPauseFocusNode);
          return;
        }

        // 2. If focus is outside the player, pull it back to play/pause.
        final inPlayer =
            current.context != null &&
            current.context!.mounted &&
            current.context!
                    .findAncestorWidgetOfExactType<LiveTvEmbeddedPlayer>() !=
                null;

        if (!inPlayer) {
          _requestFocusOrFallback(_playPauseFocusNode);
        }
      });
    }
  }

  /// Requests focus on [node], falling back to [_playerAnchorFocusNode]
  /// if the primary target cannot receive focus. This prevents focus
  /// from being silently lost when the widget tree rebuilds during
  /// playback state changes.
  void _requestFocusOrFallback(FocusNode primary) {
    if (primary.canRequestFocus) {
      primary.requestFocus();
      return;
    }
    if (_playerAnchorFocusNode.canRequestFocus) {
      _playerAnchorFocusNode.requestFocus();
    }
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
      if (_controlsVisible) {
        _startControlsTimer();
        _focusPlayPauseIfControlsVisible();
      } else {
        _controlsTimer?.cancel();
      }
    });
  }

  void _showControlsTemporarily() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
      _startControlsTimer();
      _focusPlayPauseIfControlsVisible();
    } else {
      _startControlsTimer();
    }
  }

  /// Remote Select/OK handling.
  ///
  /// In inline mode, Select always toggles playback so the user is not
  /// forced into a two-tap sequence (hide controls → play). Controls
  /// visibility is managed independently via [_showControlsTemporarily].
  /// In fullscreen mode, Select toggles controls visibility when visible
  /// and toggles playback when controls are hidden.
  void _handleSelectKey() {
    if (!widget.isFullscreen) {
      widget.controller.inlinePlayerController?.togglePlayPause();
      _showControlsTemporarily();
      return;
    }

    if (_controlsVisible) {
      _toggleControls();
      return;
    }
    widget.controller.inlinePlayerController?.togglePlayPause();
    _showControlsTemporarily();
  }

  IconData _getAspectRatioIcon(AspectRatioMode mode) {
    switch (mode) {
      case AspectRatioMode.fit:
        return Icons.fit_screen_rounded;
      case AspectRatioMode.fill:
        return Icons.crop_free_rounded;
      case AspectRatioMode.ratio16x9:
        return Icons.crop_16_9_rounded;
      case AspectRatioMode.ratio4x3:
        return Icons.crop_5_4_rounded;
      case AspectRatioMode.stretch:
        return Icons.aspect_ratio_rounded;
      case AspectRatioMode.zoom:
        return Icons.zoom_out_map_rounded;
      case AspectRatioMode.original:
        return Icons.crop_original_rounded;
    }
  }

  void _showHudToast(String message) {
    _hudToastTimer?.cancel();
    setState(() => _hudToastText = message);
    _hudToastTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _hudToastText = null);
      }
    });
  }

  double _calculateFullscreenAspectRatio(
    AspectRatioMode mode,
    Size screenSize,
  ) {
    switch (mode) {
      case AspectRatioMode.ratio16x9:
        return 16.0 / 9.0;
      case AspectRatioMode.ratio4x3:
        return 4.0 / 3.0;
      case AspectRatioMode.fit:
      case AspectRatioMode.fill:
      case AspectRatioMode.stretch:
      case AspectRatioMode.zoom:
      case AspectRatioMode.original:
        return screenSize.height > 0
            ? (screenSize.width / screenSize.height)
            : (16.0 / 9.0);
    }
  }

  void _cycleAspectRatio(PlayerController playerCtrl) {
    final current = playerCtrl.playbackController.engine.aspectRatioRx.value;
    final modes = AspectRatioMode.values;
    final nextIndex = (modes.indexOf(current) + 1) % modes.length;
    final nextMode = modes[nextIndex];
    playerCtrl.setAspectRatio(nextMode);
    _showHudToast('Aspect Ratio: ${nextMode.displayName}');
  }

  void _openAudioTrackSheet(
    BuildContext context,
    PlayerController playerCtrl,
  ) async {
    final tracks = await playerCtrl.getAvailableAudioTracks();
    if (!context.mounted) return;
    if (tracks.isEmpty) {
      _showHudToast('No alternate audio tracks available');
      return;
    }
    _showHudToast('Audio Tracks');
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E222A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Obx(() {
          final selected = playerCtrl.selectedAudioTrackRx.value;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.audiotrack_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Audio Tracks',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  Flexible(
                    child: AudioTrackSelector(
                      tracks: tracks,
                      selectedTrackId: selected,
                      onSelected: (trackId) {
                        playerCtrl.setAudioTrack(trackId);
                        _showHudToast('Audio: $trackId');
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _openSubtitleSheet(
    BuildContext context,
    PlayerController playerCtrl,
  ) async {
    final tracks = await playerCtrl.getAvailableSubtitleTracks();
    if (!context.mounted) return;
    if (tracks.isEmpty) {
      _showHudToast('No subtitles available');
      return;
    }
    _showHudToast('Subtitles');
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E222A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Obx(() {
          final selected = playerCtrl.selectedSubtitleTrackRx.value;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.subtitles_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Subtitles',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  Flexible(
                    child: SubtitleSelector(
                      tracks: tracks,
                      selectedTrackId: selected,
                      onSelected: (trackId) {
                        playerCtrl.setSubtitleTrack(trackId);
                        _showHudToast('Subtitles: $trackId');
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildQuickZapperDrawer() {
    final channels = widget.controller.filteredChannels.isNotEmpty
        ? widget.controller.filteredChannels
        : widget.controller.channels;
    final activeId = widget.controller.activePlayingChannel.value?.id;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 320.0,
        height: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: const Color(0xEE0D1117),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black87,
              blurRadius: 24.0,
              offset: Offset(4, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.tv_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Quick Channel Zapper',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TvFocusable(
                    onTap: () => setState(() => _quickZapperOpen = false),
                    scale: 1.05,
                    borderRadius: BorderRadius.circular(8),
                    child: IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _quickZapperOpen = false),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: channels.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, idx) {
                  final ch = channels[idx];
                  final isCurrent = ch.id == activeId;
                  final rawLogo = ch.thumbnail ?? ch.poster ?? ch.backdrop;
                  final logoUrl = ImageUrlFormatter.format(rawLogo, item: ch);
                  return TvFocusable(
                    onTap: () {
                      widget.controller.openChannel(ch);
                      _showHudToast('Channel: ${ch.title}');
                    },
                    borderRadius: BorderRadius.circular(8),
                    scale: 1.02,
                    child: Material(
                      color: isCurrent
                          ? AppColors.primary.withValues(alpha: 0.25)
                          : Colors.transparent,
                      child: ListTile(
                        dense: true,
                        leading: logoUrl != null && logoUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  logoUrl,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.live_tv,
                                        size: 20,
                                        color: Colors.white60,
                                      ),
                                ),
                              )
                            : const Icon(
                                Icons.live_tv,
                                size: 20,
                                color: Colors.white60,
                              ),
                        title: Text(
                          ch.title,
                          style: TextStyle(
                            color: isCurrent ? AppColors.primary : Colors.white,
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: ch.subtitle != null
                            ? Text(
                                ch.subtitle!,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: isCurrent
                            ? const Icon(
                                Icons.play_circle_fill,
                                color: AppColors.primary,
                                size: 18,
                              )
                            : null,
                        onTap: () {
                          widget.controller.openChannel(ch);
                          _showHudToast('Channel: ${ch.title}');
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(LiveTvEmbeddedPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When transitioning between fullscreen and inline, if the player was paused
    // (e.g. from an interruption), resume playback. Do not trigger play() if already
    // playing or buffering so we don't disrupt decoding or cause duplicate re-buffers.
    if (oldWidget.isFullscreen != widget.isFullscreen) {
      final playerCtrl = widget.controller.inlinePlayerController;
      if (playerCtrl != null) {
        final state = playerCtrl.playbackController.engine.stateRx.value;
        if (state == PlaybackState.paused) {
          playerCtrl.resume();
        }
      }
    }
  }

  @override
  void dispose() {
    _hudToastTimer?.cancel();
    _controlsTimer?.cancel();
    _playPauseFocusNode.dispose();
    _bottomPlayPauseFocusNode.dispose();
    _stopFocusNode.dispose();
    _favoriteFocusNode.dispose();
    _aspectRatioFocusNode.dispose();
    _audioFocusNode.dispose();
    _subtitleFocusNode.dispose();
    _quickZapperFocusNode.dispose();
    _fullscreenFocusNode.dispose();
    _playerAnchorFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final activeChannel = widget.controller.activePlayingChannel.value;
      final playerCtrl = widget.controller.inlinePlayerController;

      final activeWidget = activeChannel != null && playerCtrl != null
          ? _buildActivePlayer(
              activeChannel,
              playerCtrl,
              isFullscreen: widget.isFullscreen,
            )
          : _buildFeaturedHero(isFullscreen: widget.isFullscreen);

      final screenSize = MediaQuery.sizeOf(context);
      final isLandscape =
          MediaQuery.of(context).orientation == Orientation.landscape;
      final aspectMode =
          playerCtrl?.playbackController.engine.aspectRatioRx.value ??
              AspectRatioMode.fit;
      final double targetAspectRatio = widget.isFullscreen
          ? _calculateFullscreenAspectRatio(aspectMode, screenSize)
          : (16 / 9);

      return Container(
        width: double.infinity,
        height: widget.isFullscreen ? double.infinity : null,
        color: Colors.black,
        child: Padding(
          padding: widget.isFullscreen
              ? EdgeInsets.zero
              : (isLandscape
                    ? const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0)
                    : const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
                        AppSpacing.xs,
                      )),
          child: Center(
            child: AspectRatio(
              aspectRatio: targetAspectRatio,
              child: Container(
                decoration: widget.isFullscreen
                    ? const BoxDecoration(color: Colors.black)
                    : BoxDecoration(
                        color: Colors.black,
                        borderRadius: AppRadius.large,
                        border: Border.all(
                          color: activeChannel != null
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.1),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: activeChannel != null
                                ? AppColors.primary.withValues(alpha: 0.25)
                                : Colors.black.withValues(alpha: 0.4),
                            blurRadius: 16.0,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                child: ClipRRect(
                  borderRadius: widget.isFullscreen
                      ? BorderRadius.zero
                      : AppRadius.large,
                  child: activeWidget,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildActivePlayer(
    MediaItem channel,
    PlayerController playerCtrl, {
    required bool isFullscreen,
  }) {
    final channelNum = channel is Channel ? channel.number : null;
    final formattedTitle = TitleFormatter.formatChannelTitle(channel.title);
    final categoryName = channel.genres.isNotEmpty
        ? channel.genres.first
        : (channel.metadata['category_name'] as String? ?? 'Live TV');

    return Focus(
      focusNode: _playerAnchorFocusNode,
      canRequestFocus: true,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (node.hasPrimaryFocus && event is KeyDownEvent) {
          _showControlsTemporarily();
          if (_playPauseFocusNode.canRequestFocus) {
            _playPauseFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: TvPlayerKeyboard(
        autofocus: widget.autofocus,
      onAnyKey: _showControlsTemporarily,
      onToggleControls: _handleSelectKey,
      onPlayPause: () {
        playerCtrl.togglePlayPause();
        final isPlaying =
            playerCtrl.playbackController.engine.stateRx.value ==
            PlaybackState.playing;
        _showHudToast(isPlaying ? 'Play' : 'Pause');
      },
      onStop: () {
        widget.controller.stopInlinePlayer();
        _showHudToast('Stop');
      },
      onChannelUp: () {
        widget.controller.playNextChannel();
        final current = widget.controller.activePlayingChannel.value;
        if (current != null) {
          _showHudToast(
            'CH+ : ${TitleFormatter.formatChannelTitle(current.title)}',
          );
        }
      },
      onChannelDown: () {
        widget.controller.playPreviousChannel();
        final current = widget.controller.activePlayingChannel.value;
        if (current != null) {
          _showHudToast(
            'CH- : ${TitleFormatter.formatChannelTitle(current.title)}',
          );
        }
      },
      onBack: () {
        if (_quickZapperOpen) {
          setState(() => _quickZapperOpen = false);
          return true;
        }
        return false;
      },
      child: PlayerTouchGestureOverlay(
        onTap: _toggleControls,
        onVolumeChanged: (vol) => playerCtrl.setVolume(vol),
        controls: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Buffering / Loading State Indicator
            Obx(() {
              final state = playerCtrl.playbackController.engine.stateRx.value;
              if (state == PlaybackState.loading ||
                  state == PlaybackState.buffering) {
                return IgnorePointer(
                  ignoring: true,
                  child: Container(
                    color: Colors.black45,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 36.0,
                              height: 36.0,
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                                strokeWidth: 3.0,
                              ),
                            ),
                            AppSpacing.heightSM,
                            Text(
                              state == PlaybackState.loading
                                  ? 'Connecting to live stream...'
                                  : 'Buffering...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 4.0),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
              if (state == PlaybackState.error) {
                return Container(
                  color: Colors.black87,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 36.0,
                          ),
                          AppSpacing.heightXS,
                          const Text(
                            'Unable to load live stream',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          AppSpacing.heightSM,
                          ElevatedButton.icon(
                            onPressed: () =>
                                widget.controller.openChannel(channel),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text(
                              'Retry',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryContainer,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),

            // 4. Center Glowing Play/Pause Button
            IgnorePointer(
              ignoring: !_controlsVisible,
              child: ExcludeFocus(
                excluding: !_controlsVisible && !_playPauseFocusNode.hasFocus,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Center(
                    child: Obx(() {
                      final state =
                          playerCtrl.playbackController.engine.stateRx.value;
                      final isPlaying = state == PlaybackState.playing;

                      return TvFocusable(
                        focusNode: _playPauseFocusNode,
                        onFocusChange: (hasFocus) {
                          if (hasFocus) {
                            _showControlsTemporarily();
                          } else {
                            _startControlsTimer();
                          }
                        },
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent) {
                            if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
                                widget.onMoveUp != null) {
                              widget.onMoveUp!();
                              return KeyEventResult.handled;
                            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                              if (_bottomPlayPauseFocusNode.canRequestFocus) {
                                _bottomPlayPauseFocusNode.requestFocus();
                                return KeyEventResult.handled;
                              }
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                        onTap: () {
                          _showControlsTemporarily();
                          playerCtrl.togglePlayPause();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted || !_controlsVisible) return;
                            _playPauseFocusNode.requestFocus();
                          });
                        },
                        scale: 1.08,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.all(14.0),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.8),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 18.0,
                              ),
                            ],
                          ),
                          child: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: isFullscreen ? 40.0 : 30.0,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),

            // 5. Top Gradient Bar & Channel Info
            IgnorePointer(
              ignoring: !_controlsVisible,
              child: ExcludeFocus(
                excluding: !_controlsVisible,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: isFullscreen ? AppSpacing.md : 2.0,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black87,
                            Colors.black45,
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        top: isFullscreen,
                        bottom: false,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final bool isCompact = constraints.maxWidth < 350;
                            final bool isUltraCompact =
                                constraints.maxWidth < 220;
                            final bool isMicro = constraints.maxWidth < 160;

                            return Row(
                              children: [
                                const SizedBox(width: AppSpacing.xs),
                                // Red Live Badge
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMicro
                                        ? 4.0
                                        : (isUltraCompact ? 5.0 : 6.0),
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.9),
                                    borderRadius: AppRadius.pill,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6.0,
                                        height: 6.0,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      if (!isMicro) ...[
                                        const SizedBox(width: 4.0),
                                        const Text(
                                          'LIVE',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                SizedBox(width: isUltraCompact ? 4.0 : 8.0),

                                // Channel Number
                                if (!isUltraCompact &&
                                    channelNum != null &&
                                    channelNum.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6.0,
                                      vertical: 2.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.18,
                                      ),
                                      borderRadius: BorderRadius.circular(4.0),
                                    ),
                                    child: Text(
                                      channelNum,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6.0),
                                ],

                                // Channel Title
                                Expanded(
                                  child: Text(
                                    formattedTitle,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isUltraCompact ? 11.5 : 13.5,
                                      fontWeight: FontWeight.w700,
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black87,
                                          blurRadius: 4.0,
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                // Category Tag
                                if (!isCompact) ...[
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 80.0,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6.0,
                                        vertical: 2.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryContainer
                                            .withValues(alpha: 0.4),
                                        borderRadius: AppRadius.pill,
                                        border: Border.all(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.4,
                                          ),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        categoryName.toUpperCase(),
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 9.0,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4.0),
                                ],

                                // Stop & Close Button
                                TvFocusable(
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent &&
                                        event.logicalKey == LogicalKeyboardKey.arrowUp &&
                                        widget.onMoveUp != null) {
                                      widget.onMoveUp!();
                                      return KeyEventResult.handled;
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  onTap: () {
                                    if (isFullscreen) {
                                      widget.controller.exitFullscreen();
                                    } else {
                                      widget.controller.stopInlinePlayer();
                                    }
                                  },
                                  scale: 1.05,
                                  borderRadius: BorderRadius.circular(20),
                                  child: IconButton(
                                    padding: EdgeInsets.all(
                                      isUltraCompact ? 2.0 : 4.0,
                                    ),
                                    constraints: const BoxConstraints(),
                                    icon: Container(
                                      padding: EdgeInsets.all(
                                        isUltraCompact ? 2.0 : 4.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.7,
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: Colors.white,
                                        size: isUltraCompact ? 13.0 : 15.0,
                                      ),
                                    ),
                                    tooltip: isFullscreen
                                        ? 'Exit Fullscreen'
                                        : 'Stop and Close',
                                    onPressed: null,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 6. Bottom Controls Overlay & Fullscreen Expand Button
            IgnorePointer(
              ignoring: !_controlsVisible,
              child: ExcludeFocus(
                excluding: !_controlsVisible,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: isFullscreen ? AppSpacing.md : 2.0,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black87,
                            Colors.black45,
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        bottom: isFullscreen,
                        child: LayoutBuilder(
                          builder: (context, bottomConstraints) {
                            final isCompact = bottomConstraints.maxWidth < 350;
                            final isUltraCompact =
                                bottomConstraints.maxWidth < 220;
                            final isMicro = bottomConstraints.maxWidth < 160;
                            return FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Play/Pause Icon Button
                                  Obx(() {
                                    final state = playerCtrl
                                        .playbackController
                                        .engine
                                        .stateRx
                                        .value;
                                    final isPlaying =
                                        state == PlaybackState.playing;

                                    return TvFocusable(
                                      focusNode: _bottomPlayPauseFocusNode,
                                      onKeyEvent: _handleBottomControlKeyEvent,
                                      onTap: () {
                                        _showControlsTemporarily();
                                        playerCtrl.togglePlayPause();
                                      },
                                      scale: 1.08,
                                      borderRadius: BorderRadius.circular(20),
                                      child: IconButton(
                                        padding: EdgeInsets.all(
                                          isCompact
                                              ? 2.0
                                              : (isUltraCompact ? 2.0 : 4.0),
                                        ),
                                        constraints: BoxConstraints.tightFor(
                                          width: isCompact ? 28.0 : 36.0,
                                          height: isCompact ? 28.0 : 36.0,
                                        ),
                                        icon: Icon(
                                          isPlaying
                                              ? Icons
                                                    .pause_circle_filled_rounded
                                              : Icons
                                                    .play_circle_filled_rounded,
                                          color: AppColors.primary,
                                          size: isCompact
                                              ? 20.0
                                              : (isUltraCompact
                                                    ? 22.0
                                                    : (isFullscreen
                                                          ? 26.0
                                                          : 30.0)),
                                        ),
                                        onPressed: null,
                                      ),
                                    );
                                  }),
                                  SizedBox(width: isUltraCompact ? 2.0 : 4.0),

                                  // Stop Button: keep this visible even on compact layouts so the
                                  // user can always stop playback without relying on a secondary menu.
                                  TvFocusable(
                                    focusNode: _stopFocusNode,
                                    onKeyEvent: _handleBottomControlKeyEvent,
                                    onTap: () {
                                      _showControlsTemporarily();
                                      widget.controller.stopInlinePlayer();
                                      _showHudToast('Playback Stopped');
                                    },
                                    scale: 1.05,
                                    borderRadius: BorderRadius.circular(20),
                                    child: IconButton(
                                      padding: EdgeInsets.all(
                                        isCompact ? 2.0 : 4.0,
                                      ),
                                      constraints: BoxConstraints.tightFor(
                                        width: isCompact ? 28.0 : 36.0,
                                        height: isCompact ? 28.0 : 36.0,
                                      ),
                                      icon: Icon(
                                        Icons.stop_circle_outlined,
                                        color: Colors.white70,
                                        size: isCompact ? 18.0 : 24.0,
                                      ),
                                      tooltip: 'Stop Playback',
                                      onPressed: null,
                                    ),
                                  ),
                                  const SizedBox(width: 4.0),

                                  // Program Subtitle or Info
                                  if (!isCompact && !isMicro)
                                    Flexible(
                                      child: Text(
                                        channel.subtitle ??
                                            (channel.genres.isNotEmpty
                                                ? channel.genres.join(' • ')
                                                : 'Live Broadcast'),
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: isUltraCompact ? 9.5 : 11.0,
                                          fontWeight: FontWeight.w500,
                                          shadows: const [
                                            Shadow(
                                              color: Colors.black87,
                                              blurRadius: 4.0,
                                            ),
                                          ],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  else
                                    const SizedBox(width: 8.0),
                                  SizedBox(width: isUltraCompact ? 2.0 : 4.0),

                                  // Favorite Toggle
                                  TvFocusable(
                                    focusNode: _favoriteFocusNode,
                                    onKeyEvent: _handleBottomControlKeyEvent,
                                    onTap: () {
                                      _showControlsTemporarily();
                                      final wasFav = widget.controller.favorites
                                          .any((f) => f.id == channel.id);
                                      widget.controller.toggleFavorite(channel);
                                      _showHudToast(!wasFav
                                          ? 'Added to Favorites'
                                          : 'Removed from Favorites');
                                    },
                                    scale: 1.05,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Obx(() {
                                      final isFav = widget.controller.favorites
                                          .any((f) => f.id == channel.id);
                                      return IconButton(
                                        padding: EdgeInsets.all(
                                          isCompact ? 2.0 : 4.0,
                                        ),
                                        constraints: BoxConstraints.tightFor(
                                          width: isCompact ? 28.0 : 36.0,
                                          height: isCompact ? 28.0 : 36.0,
                                        ),
                                        tooltip: isFav
                                            ? 'Remove Favorite'
                                            : 'Add Favorite',
                                        icon: Icon(
                                          isFav
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          color: isFav
                                              ? Colors.redAccent
                                              : Colors.white70,
                                          size: isCompact
                                              ? 16.0
                                              : (isUltraCompact ? 18.0 : 20.0),
                                        ),
                                        onPressed: null,
                                      );
                                    }),
                                  ),
                                  const SizedBox(width: 2.0),

                                  if (isFullscreen && !isCompact) ...[
                                    // Aspect Ratio Cycle Button
                                    TvFocusable(
                                      focusNode: _aspectRatioFocusNode,
                                      onKeyEvent: _handleBottomControlKeyEvent,
                                      onTap: () {
                                        _showControlsTemporarily();
                                        _cycleAspectRatio(playerCtrl);
                                      },
                                      scale: 1.05,
                                      borderRadius: BorderRadius.circular(20),
                                      child: Obx(() {
                                        final aspectMode = playerCtrl
                                            .playbackController
                                            .engine
                                            .aspectRatioRx
                                            .value;
                                        return IconButton(
                                          padding: EdgeInsets.all(
                                            isCompact ? 2.0 : 4.0,
                                          ),
                                          constraints: BoxConstraints.tightFor(
                                            width: isCompact ? 28.0 : 36.0,
                                            height: isCompact ? 28.0 : 36.0,
                                          ),
                                          tooltip:
                                              'Aspect Ratio: ${aspectMode.displayName}',
                                          icon: Icon(
                                            _getAspectRatioIcon(aspectMode),
                                            color: Colors.white,
                                            size: isCompact ? 18.0 : 22.0,
                                          ),
                                          onPressed: null,
                                        );
                                      }),
                                    ),
                                    const SizedBox(width: 2.0),

                                    // Audio Track Selector Button
                                    TvFocusable(
                                      focusNode: _audioFocusNode,
                                      onKeyEvent: _handleBottomControlKeyEvent,
                                      onTap: () {
                                        _showControlsTemporarily();
                                        _openAudioTrackSheet(
                                          context,
                                          playerCtrl,
                                        );
                                      },
                                      scale: 1.05,
                                      borderRadius: BorderRadius.circular(20),
                                      child: IconButton(
                                        padding: EdgeInsets.all(
                                          isCompact ? 2.0 : 4.0,
                                        ),
                                        constraints: BoxConstraints.tightFor(
                                          width: isCompact ? 28.0 : 36.0,
                                          height: isCompact ? 28.0 : 36.0,
                                        ),
                                        tooltip: 'Audio Tracks',
                                        icon: Icon(
                                          Icons.audiotrack_rounded,
                                          color: Colors.white,
                                          size: isCompact ? 18.0 : 22.0,
                                        ),
                                        onPressed: null,
                                      ),
                                    ),
                                    const SizedBox(width: 2.0),

                                    // Subtitles Selector Button
                                    TvFocusable(
                                      focusNode: _subtitleFocusNode,
                                      onKeyEvent: _handleBottomControlKeyEvent,
                                      onTap: () {
                                        _showControlsTemporarily();
                                        _openSubtitleSheet(
                                          context,
                                          playerCtrl,
                                        );
                                      },
                                      scale: 1.05,
                                      borderRadius: BorderRadius.circular(20),
                                      child: IconButton(
                                        padding: EdgeInsets.all(
                                          isCompact ? 2.0 : 4.0,
                                        ),
                                        constraints: BoxConstraints.tightFor(
                                          width: isCompact ? 28.0 : 36.0,
                                          height: isCompact ? 28.0 : 36.0,
                                        ),
                                        tooltip: 'Subtitles',
                                        icon: Icon(
                                          Icons.subtitles_rounded,
                                          color: Colors.white,
                                          size: isCompact ? 18.0 : 22.0,
                                        ),
                                        onPressed: null,
                                      ),
                                    ),
                                    const SizedBox(width: 2.0),

                                    // Quick Channel Zapper Drawer Toggle
                                    TvFocusable(
                                      focusNode: _quickZapperFocusNode,
                                      onKeyEvent: _handleBottomControlKeyEvent,
                                      onTap: () {
                                        _showControlsTemporarily();
                                        setState(() {
                                          _quickZapperOpen = !_quickZapperOpen;
                                          if (_quickZapperOpen) {
                                            _controlsTimer?.cancel();
                                          }
                                        });
                                        _showHudToast(_quickZapperOpen
                                            ? 'Quick Channels: Open'
                                            : 'Quick Channels: Closed');
                                      },
                                      scale: 1.05,
                                      borderRadius: BorderRadius.circular(20),
                                      child: IconButton(
                                        padding: EdgeInsets.all(
                                          isCompact ? 2.0 : 4.0,
                                        ),
                                        constraints: BoxConstraints.tightFor(
                                          width: isCompact ? 28.0 : 36.0,
                                          height: isCompact ? 28.0 : 36.0,
                                        ),
                                        tooltip: 'Quick Channel List',
                                        icon: Icon(
                                          _quickZapperOpen
                                              ? Icons.view_sidebar_rounded
                                              : Icons.view_sidebar_outlined,
                                          color: _quickZapperOpen
                                              ? AppColors.primary
                                              : Colors.white,
                                          size: isCompact ? 18.0 : 22.0,
                                        ),
                                        onPressed: null,
                                      ),
                                    ),
                                    const SizedBox(width: 2.0),
                                  ],

                                  // Picture-in-Picture Button (⧉)
                                  if (!isCompact &&
                                      !isUltraCompact &&
                                      Platform.isAndroid) ...[
                                    TvFocusable(
                                      onKeyEvent: _handleBottomControlKeyEvent,
                                      onTap: () {
                                        _showControlsTemporarily();
                                        playerCtrl.enterPictureInPicture();
                                      },
                                      scale: 1.05,
                                      borderRadius: BorderRadius.circular(20),
                                      child: IconButton(
                                        padding: EdgeInsets.all(
                                          isCompact ? 2.0 : 4.0,
                                        ),
                                        constraints: BoxConstraints.tightFor(
                                          width: isCompact ? 28.0 : 36.0,
                                          height: isCompact ? 28.0 : 36.0,
                                        ),
                                        tooltip: 'Picture-in-Picture',
                                        icon: const Icon(
                                          Icons.picture_in_picture_alt_rounded,
                                          color: Colors.white,
                                          size: 22.0,
                                        ),
                                        onPressed: null,
                                      ),
                                    ),
                                    const SizedBox(width: 4.0),
                                  ],

                                  // Fullscreen Expand Button (⛶)
                                  TvFocusable(
                                    focusNode: _fullscreenFocusNode,
                                    onKeyEvent: _handleBottomControlKeyEvent,
                                    onTap: () {
                                      _showControlsTemporarily();
                                      if (isFullscreen) {
                                        widget.controller.exitFullscreen();
                                      } else {
                                        widget.controller.expandToFullscreen();
                                      }
                                    },
                                    scale: 1.05,
                                    borderRadius: BorderRadius.circular(20),
                                    child: IconButton(
                                      padding: EdgeInsets.all(
                                        isCompact
                                            ? 2.0
                                            : (isUltraCompact ? 2.0 : 4.0),
                                      ),
                                      constraints: BoxConstraints.tightFor(
                                        width: isCompact ? 28.0 : 36.0,
                                        height: isCompact ? 28.0 : 36.0,
                                      ),
                                      tooltip: isFullscreen
                                          ? 'Exit Fullscreen'
                                          : 'Expand to Fullscreen',
                                      icon: Icon(
                                        isFullscreen
                                            ? Icons.fullscreen_exit_rounded
                                            : Icons.fullscreen_rounded,
                                        color: Colors.white,
                                        size: isCompact
                                            ? 18.0
                                            : (isUltraCompact ? 22.0 : 26.0),
                                      ),
                                      onPressed: null,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 7. On-Screen HUD Toast Notification
            if (_hudToastText != null)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: isFullscreen ? 60.0 : 20.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.6),
                        width: 1.0,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 10.0),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.primary,
                          size: 18.0,
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          _hudToastText!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 8. Quick Channel Zapper Drawer (Fullscreen only)
            if (isFullscreen && _quickZapperOpen) _buildQuickZapperDrawer(),
          ],
        ),
        child: Obx(() {
          playerCtrl.playbackController.engine.engineKindRx.value;
          final adapter = playerCtrl.playbackController.engine.adapter;
          return IgnorePointer(
            ignoring: true,
            child: ColoredBox(
              color: Colors.black,
              child: KeepScreenOn(child: adapter.buildPlayerWidget()),
            ),
          );
        }),
      ),
    ),
    );
  }

  Widget _buildFeaturedHero({bool isFullscreen = false}) {
    final featured =
        widget.controller.featuredChannel.value ??
        widget.controller.channels.firstOrNull;

    if (featured == null) {
      return Container(
        color: const Color(0xFF161A1D),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tv_rounded, color: AppColors.primary, size: 38.0),
            AppSpacing.heightSM,
            const Text(
              'Select a channel to watch live',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final posterUrl = featured.poster ?? featured.thumbnail;
    final hasPoster = posterUrl != null && posterUrl.isNotEmpty;
    final formattedTitle = TitleFormatter.formatChannelTitle(featured.title);
    final categoryName = featured.genres.isNotEmpty
        ? featured.genres.first
        : (featured.metadata['category_name'] as String? ?? 'Featured Live');

    return TvFocusable(
      focusNode: _playerAnchorFocusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            if (widget.onMoveDown != null) {
              widget.onMoveDown!();
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            if (widget.onMoveUp != null) {
              widget.onMoveUp!();
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      onTap: () => widget.controller.openChannel(featured),
      scale: 1.02,
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          if (hasPoster)
            Image.network(
              posterUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const ChannelPlaceholder(iconSize: 48.0, fontSize: 13.0),
            )
          else
            const ChannelPlaceholder(iconSize: 48.0, fontSize: 13.0),

          // Cinematic Vignette Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.9),
                ],
              ),
            ),
          ),

          // Top Badge
          Positioned(
            top: isFullscreen ? AppSpacing.lg : AppSpacing.sm,
            left: AppSpacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 3.0,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.8),
                borderRadius: AppRadius.pill,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Colors.amber,
                    size: 14.0,
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    categoryName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center Glowing Play Button
          Center(
            child: Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.6),
                    blurRadius: 24.0,
                    spreadRadius: 2.0,
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.black,
                size: 32.0,
              ),
            ),
          ),

          // Bottom Channel Information
          Positioned(
            bottom: isFullscreen ? AppSpacing.lg : AppSpacing.sm,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formattedTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.0,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 6.0),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        featured.subtitle ?? 'Tap to start watching live',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 4.0),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 5.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: AppRadius.pill,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.0,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.live_tv_rounded,
                        color: Colors.white,
                        size: 14.0,
                      ),
                      SizedBox(width: 4.0),
                      Text(
                        'Watch',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
