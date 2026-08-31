import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/aspect_ratio_mode.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/modules/free_live_tv/controllers/free_live_tv_controller.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';
import 'package:stream_hub/modules/player/widgets/audio_track_selector.dart';
import 'package:stream_hub/modules/player/widgets/player_touch_gesture_overlay.dart';
import 'package:stream_hub/modules/player/widgets/subtitle_selector.dart'
    hide AudioTrackSelector;
import 'package:stream_hub/shared/widgets/channel_placeholder.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

class FreeTvEmbeddedPlayer extends StatefulWidget {
  final FreeLiveTvController controller;
  final bool isFullscreen;

  const FreeTvEmbeddedPlayer({
    super.key,
    required this.controller,
    this.isFullscreen = false,
  });

  @override
  State<FreeTvEmbeddedPlayer> createState() => _FreeTvEmbeddedPlayerState();
}

class _FreeTvEmbeddedPlayerState extends State<FreeTvEmbeddedPlayer> {
  bool _controlsVisible = true;
  Timer? _controlsTimer;
  bool _quickZapperOpen = false;
  String? _hudToastText;
  Timer? _hudToastTimer;

  @override
  void initState() {
    super.initState();
    _startControlsTimer();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _controlsVisible) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
      if (_controlsVisible) {
        _startControlsTimer();
      } else {
        _controlsTimer?.cancel();
      }
    });
  }

  void _showControlsTemporarily() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _startControlsTimer();
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
                  AudioTrackSelector(
                    tracks: tracks,
                    selectedTrackId: selected,
                    onSelected: (trackId) {
                      playerCtrl.setAudioTrack(trackId);
                      _showHudToast('Audio: $trackId');
                      Navigator.of(ctx).pop();
                    },
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
                  SubtitleSelector(
                    tracks: tracks,
                    selectedTrackId: selected,
                    onSelected: (trackId) {
                      playerCtrl.setSubtitleTrack(trackId);
                      _showHudToast('Subtitles: $trackId');
                      Navigator.of(ctx).pop();
                    },
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
                  final logo = ch.logo;
                  final subtitle = ch.country.isNotEmpty
                      ? (ch.categories.isNotEmpty
                          ? '${ch.categories.first} • ${ch.country}'
                          : ch.country)
                      : (ch.categories.isNotEmpty
                          ? ch.categories.first
                          : 'Free Live TV');
                  return Material(
                    color: isCurrent
                        ? AppColors.primary.withValues(alpha: 0.25)
                        : Colors.transparent,
                    child: ListTile(
                      dense: true,
                      leading: logo != null && logo.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                logo,
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
                        ch.name,
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
                      subtitle: Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isCurrent
                          ? const Icon(
                              Icons.play_circle_fill,
                              color: AppColors.primary,
                              size: 18,
                            )
                          : null,
                      onTap: () {
                        widget.controller.openChannel(ch);
                        _showHudToast('Channel: ${ch.name}');
                      },
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
  void didUpdateWidget(FreeTvEmbeddedPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If orientation or mode changed between fullscreen and inline, ensure playback continues!
    if (oldWidget.isFullscreen != widget.isFullscreen) {
      final playerCtrl = widget.controller.inlinePlayerController;
      if (playerCtrl != null) {
        final state = playerCtrl.playbackController.engine.stateRx.value;
        if (!state.isStoppedLike && state != PlaybackState.error) {
          playerCtrl.play();
        }
      }
    }
  }

  @override
  void dispose() {
    _hudToastTimer?.cancel();
    _controlsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final activeChannel = widget.controller.activePlayingChannel.value;
      final playerCtrl = widget.controller.inlinePlayerController;

      if (widget.isFullscreen) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: activeChannel != null && playerCtrl != null
              ? _buildActivePlayer(
                  activeChannel,
                  playerCtrl,
                  isFullscreen: true,
                )
              : _buildFeaturedHero(isFullscreen: true),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
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
              borderRadius: AppRadius.large,
              child: activeChannel != null && playerCtrl != null
                  ? _buildActivePlayer(
                      activeChannel,
                      playerCtrl,
                      isFullscreen: false,
                    )
                  : _buildFeaturedHero(isFullscreen: false),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildActivePlayer(
    FreeTvChannel channel,
    PlayerController playerCtrl, {
    required bool isFullscreen,
  }) {
    final categoryName = channel.categories.isNotEmpty
        ? channel.categories.first
        : 'Free TV';
    final infoText = channel.network != null && channel.network!.isNotEmpty
        ? '${channel.network} • ${channel.country}'
        : (channel.country.isNotEmpty
            ? '${channel.country} • Free Live TV'
            : 'Free Live TV');

    return PlayerTouchGestureOverlay(
      onTap: _toggleControls,
      onVolumeChanged: (vol) => playerCtrl.setVolume(vol),
      controls: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Buffering / Loading State Indicator
          Obx(() {
            final state = playerCtrl.playbackController.engine.stateRx.value;
            final controllerIsLoading = widget.controller.isPlayerLoading.value;
            final statusMsg = widget.controller.playbackStatusMessage.value;
            final isBuffering = state == PlaybackState.buffering;
            final isLoading = controllerIsLoading ||
                state == PlaybackState.loading ||
                isBuffering;

            if (isLoading) {
              return IgnorePointer(
                ignoring: true,
                child: Container(
                  color: Colors.black45,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LoadingPercentIndicator(
                          progress: widget.controller.loadProgress.value,
                        ),
                        AppSpacing.heightSM,
                        Text(
                          statusMsg.isNotEmpty
                              ? statusMsg
                              : (state == PlaybackState.loading
                                  ? 'Connecting to live stream...'
                                  : 'Buffering...'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 4.0),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 36.0,
                      ),
                      AppSpacing.heightXS,
                      Text(
                        statusMsg.isNotEmpty
                            ? statusMsg
                            : 'Unable to load live stream',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      AppSpacing.heightSM,
                      ElevatedButton.icon(
                        onPressed: () => widget.controller.openChannel(channel),
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
              );
            }
            return const SizedBox.shrink();
          }),

          // 2. Center Glowing Play/Pause Button
          IgnorePointer(
            ignoring: !_controlsVisible,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Center(
                child: Obx(() {
                  final state =
                      playerCtrl.playbackController.engine.stateRx.value;
                  final isPlaying = state == PlaybackState.playing;

                  return TvFocusable(
                    onTap: () {
                      _showControlsTemporarily();
                      playerCtrl.togglePlayPause();
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
                            color: AppColors.primary.withValues(alpha: 0.4),
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

          // 3. Top Gradient Bar & Channel Info
          IgnorePointer(
            ignoring: !_controlsVisible,
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
                    child: Row(
                      children: [
                        const SizedBox(width: AppSpacing.xs),
                        // Red Live Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.0,
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
                          ),
                        ),
                        const SizedBox(width: 8.0),

                        // Channel Title
                        Expanded(
                          child: Text(
                            channel.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(color: Colors.black87, blurRadius: 4.0),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Multi-Stream Indicator
                        if (channel.streamUrls.length > 1) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                              vertical: 2.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: Text(
                              'Stream ${widget.controller.activeStreamIndex.value + 1}/${channel.streamUrls.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6.0),
                        ],

                        // Category Tag
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 80.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                              vertical: 2.0,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withValues(
                                alpha: 0.4,
                              ),
                              borderRadius: AppRadius.pill,
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.4),
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

                        // Stop & Close Button
                        TvFocusable(
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
                            padding: const EdgeInsets.all(4.0),
                            constraints: const BoxConstraints(),
                            icon: Container(
                              padding: const EdgeInsets.all(4.0),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1.0,
                                ),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 15.0,
                              ),
                            ),
                            tooltip: isFullscreen
                                ? 'Exit Fullscreen'
                                : 'Stop and Close',
                            onPressed: () {
                              if (isFullscreen) {
                                widget.controller.exitFullscreen();
                              } else {
                                widget.controller.stopInlinePlayer();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. Bottom Controls Overlay & Fullscreen Expand Button
          IgnorePointer(
            ignoring: !_controlsVisible,
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
                    child: Row(
                      children: [
                        // Play/Pause Icon Button
                        Obx(() {
                          final state = playerCtrl
                              .playbackController
                              .engine
                              .stateRx
                              .value;
                          final isPlaying = state == PlaybackState.playing;

                          return TvFocusable(
                            onTap: () {
                              _showControlsTemporarily();
                              playerCtrl.togglePlayPause();
                            },
                            scale: 1.08,
                            borderRadius: BorderRadius.circular(20),
                            child: IconButton(
                              padding: const EdgeInsets.all(4.0),
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                isPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_filled_rounded,
                                color: AppColors.primary,
                                size: 26.0,
                              ),
                              onPressed: () {
                                _showControlsTemporarily();
                                playerCtrl.togglePlayPause();
                              },
                            ),
                          );
                        }),
                        const SizedBox(width: 4.0),

                        // Stop Button
                        TvFocusable(
                          onTap: () {
                            _showControlsTemporarily();
                            widget.controller.stopInlinePlayer();
                          },
                          scale: 1.05,
                          borderRadius: BorderRadius.circular(20),
                          child: IconButton(
                            padding: const EdgeInsets.all(4.0),
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.stop_circle_outlined,
                              color: Colors.white70,
                              size: 24.0,
                            ),
                            tooltip: 'Stop Playback',
                            onPressed: () {
                              _showControlsTemporarily();
                              widget.controller.stopInlinePlayer();
                            },
                          ),
                        ),
                        const SizedBox(width: 6.0),

                        // Channel Info Text
                        Expanded(
                          child: Text(
                            infoText,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11.0,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(color: Colors.black87, blurRadius: 4.0),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4.0),

                        // Favorite Toggle
                        Obx(() {
                          final isFav =
                              widget.controller.favorites.any(
                                (f) => f.id == channel.id,
                              ) ||
                              channel.isFavorite;

                          return TvFocusable(
                            onTap: () {
                              _showControlsTemporarily();
                              widget.controller.toggleFavorite(channel);
                            },
                            scale: 1.05,
                            borderRadius: BorderRadius.circular(20),
                            child: IconButton(
                              padding: const EdgeInsets.all(4.0),
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                isFav
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: isFav
                                    ? Colors.redAccent
                                    : Colors.white70,
                                size: 20.0,
                              ),
                              onPressed: () {
                                _showControlsTemporarily();
                                widget.controller.toggleFavorite(channel);
                              },
                            ),
                          );
                        }),
                        const SizedBox(width: 2.0),

                        if (isFullscreen) ...[
                          // Aspect Ratio Cycle Button
                          Tooltip(
                            message: 'Cycle Aspect Ratio',
                            child: TvFocusable(
                              onTap: () {
                                _showControlsTemporarily();
                                _cycleAspectRatio(playerCtrl);
                              },
                              scale: 1.05,
                              borderRadius: BorderRadius.circular(20),
                              child: IconButton(
                                padding: const EdgeInsets.all(4.0),
                                constraints: const BoxConstraints(),
                                icon: const Icon(
                                  Icons.aspect_ratio_rounded,
                                  color: Colors.white,
                                  size: 22.0,
                                ),
                                onPressed: () {
                                  _showControlsTemporarily();
                                  _cycleAspectRatio(playerCtrl);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 2.0),

                          // Audio Track Selector Button
                          Tooltip(
                            message: 'Audio Tracks',
                            child: TvFocusable(
                              onTap: () {
                                _showControlsTemporarily();
                                _openAudioTrackSheet(context, playerCtrl);
                              },
                              scale: 1.05,
                              borderRadius: BorderRadius.circular(20),
                              child: IconButton(
                                padding: const EdgeInsets.all(4.0),
                                constraints: const BoxConstraints(),
                                icon: const Icon(
                                  Icons.audiotrack_rounded,
                                  color: Colors.white,
                                  size: 22.0,
                                ),
                                onPressed: () {
                                  _showControlsTemporarily();
                                  _openAudioTrackSheet(context, playerCtrl);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 2.0),

                          // Subtitles Selector Button
                          Tooltip(
                            message: 'Subtitles',
                            child: TvFocusable(
                              onTap: () {
                                _showControlsTemporarily();
                                _openSubtitleSheet(context, playerCtrl);
                              },
                              scale: 1.05,
                              borderRadius: BorderRadius.circular(20),
                              child: IconButton(
                                padding: const EdgeInsets.all(4.0),
                                constraints: const BoxConstraints(),
                                icon: const Icon(
                                  Icons.subtitles_rounded,
                                  color: Colors.white,
                                  size: 22.0,
                                ),
                                onPressed: () {
                                  _showControlsTemporarily();
                                  _openSubtitleSheet(context, playerCtrl);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 2.0),

                          // Quick Channel Zapper Drawer Toggle
                          Tooltip(
                            message: 'Quick Channel List',
                            child: TvFocusable(
                              onTap: () {
                                _showControlsTemporarily();
                                setState(() {
                                  _quickZapperOpen = !_quickZapperOpen;
                                });
                              },
                              scale: 1.05,
                              borderRadius: BorderRadius.circular(20),
                              child: IconButton(
                                padding: const EdgeInsets.all(4.0),
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  _quickZapperOpen
                                      ? Icons.view_sidebar_rounded
                                      : Icons.view_sidebar_outlined,
                                  color: _quickZapperOpen
                                      ? AppColors.primary
                                      : Colors.white,
                                  size: 22.0,
                                ),
                                onPressed: () {
                                  _showControlsTemporarily();
                                  setState(() {
                                    _quickZapperOpen = !_quickZapperOpen;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 2.0),
                        ],

                        // Fullscreen Expand Button
                        Tooltip(
                          message: isFullscreen
                              ? 'Exit Fullscreen'
                              : 'Expand to Fullscreen',
                          child: TvFocusable(
                            onTap: () {
                              _showControlsTemporarily();
                              if (isFullscreen) {
                                widget.controller.exitFullscreen();
                              } else {
                                widget.controller.enterFullscreen();
                              }
                            },
                            scale: 1.05,
                            borderRadius: BorderRadius.circular(20),
                            child: IconButton(
                              padding: const EdgeInsets.all(4.0),
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                isFullscreen
                                    ? Icons.fullscreen_exit_rounded
                                    : Icons.fullscreen_rounded,
                                color: Colors.white,
                                size: 26.0,
                              ),
                              onPressed: () {
                                _showControlsTemporarily();
                                if (isFullscreen) {
                                  widget.controller.exitFullscreen();
                                } else {
                                  widget.controller.enterFullscreen();
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 5. On-Screen HUD Toast Notification
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

          // 6. Quick Channel Zapper Drawer (Fullscreen only)
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
            child: adapter.buildPlayerWidget(),
          ),
        );
      }),
    );
  }

  Widget _buildFeaturedHero({bool isFullscreen = false}) {
    final featured =
        widget.controller.featuredChannel.value ??
        (widget.controller.channels.isNotEmpty
            ? widget.controller.channels.first
            : null);

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

    final logoUrl = featured.logo;
    final hasLogo = logoUrl != null && logoUrl.isNotEmpty;
    final categoryName = featured.categories.isNotEmpty
        ? featured.categories.first
        : 'Free Live';

    return TvFocusable(
      onTap: () => widget.controller.openChannel(featured),
      scale: 1.02,
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Logo Image
          if (hasLogo)
            Image.network(
              logoUrl,
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
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.25),
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
                        featured.name,
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
                        featured.country.isNotEmpty
                            ? '${featured.country} • Free Live TV'
                            : 'Tap to start watching live',
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

/// Spinner that shows a loading percentage while a channel resolves/buffers.
/// Falls back to an indeterminate spinner until progress is measurable.
class _LoadingPercentIndicator extends StatelessWidget {
  final double progress;

  const _LoadingPercentIndicator({required this.progress});

  @override
  Widget build(BuildContext context) {
    final percent = progress.clamp(0, 100).toInt();
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: progress > 0 ? progress / 100 : null,
              color: AppColors.primary,
              strokeWidth: 3.0,
              backgroundColor: Colors.white24,
            ),
          ),
          Text(
            percent < 100 ? '$percent%' : '100%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}