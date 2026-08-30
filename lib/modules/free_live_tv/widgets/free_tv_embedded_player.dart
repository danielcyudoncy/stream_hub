import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/playback_state.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/data/models/free_tv_channel.dart';
import 'package:stream_hub/modules/free_live_tv/controllers/free_live_tv_controller.dart';
import 'package:stream_hub/modules/player/controllers/player_controller.dart';
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

  @override
  void initState() {
    super.initState();
    _startControlsTimer();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Obx(() {
      final activeChannel = widget.controller.activePlayingChannel.value;
      final playerCtrl = widget.controller.inlinePlayerController;

      if (activeChannel == null || playerCtrl == null) {
        return _buildFeaturedHeroBanner(context, colorScheme);
      }

      return Obx(() {
        final playbackState =
            playerCtrl.playbackController.engine.stateRx.value;
        final isPlaying = playbackState == PlaybackState.playing;
        final isBuffering = playbackState == PlaybackState.buffering ||
            playbackState == PlaybackState.loading;
        final isError = playbackState == PlaybackState.error;
        final statusMsg = widget.controller.playbackStatusMessage.value;

        return AspectRatio(
          aspectRatio: widget.isFullscreen ? 16 / 9 : 16 / 9,
          child: Container(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Native Video Surface
                IgnorePointer(
                  ignoring: true,
                  child: playerCtrl
                      .playbackController.engine.adapter
                      .buildPlayerWidget(),
                ),

                // 2. Buffering / Loading Indicator
                if (isBuffering && !isError)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2.5,
                          ),
                          if (statusMsg.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              statusMsg,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                // 3. Error Banner & Fallback Notice
                if (isError || (statusMsg.isNotEmpty && !isBuffering))
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 360,
                        maxHeight: double.infinity,
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(AppSpacing.sm),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white24,
                            width: 1,
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Colors.amber,
                                size: 28,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                statusMsg.isNotEmpty
                                    ? statusMsg
                                    : 'This channel is currently unavailable.\nPlease try another channel.',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: () {
                                  widget.controller.openChannel(activeChannel);
                                },
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                ),
                                label: const Text('Retry'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // 4. Tap Overlay to Toggle Controls
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _toggleControls,
                  child: const SizedBox.expand(),
                ),

                // 5. Controls Overlay
                if (_controlsVisible)
                  _buildControlsOverlay(
                    context,
                    activeChannel,
                    playerCtrl,
                    isPlaying,
                  ),
              ],
            ),
          ),
        );
      });
    });
  }

  Widget _buildControlsOverlay(
    BuildContext context,
    FreeTvChannel channel,
    PlayerController playerCtrl,
    bool isPlaying,
  ) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black87,
            Colors.transparent,
            Colors.transparent,
            Colors.black87,
          ],
          stops: [0.0, 0.25, 0.75, 1.0],
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Bar (Channel Title & Actions)
          Row(
            children: [
              if (widget.isFullscreen)
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: widget.controller.exitFullscreen,
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      channel.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${channel.country} • Free Live TV',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Multi-stream indicator chip
              if (channel.streamUrls.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Stream ${widget.controller.activeStreamIndex.value + 1}/${channel.streamUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              // Stop button
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: widget.controller.stopInlinePlayer,
                tooltip: 'Stop Player',
              ),
            ],
          ),

          // Center Play / Pause toggle
          Center(
            child: IconButton(
              iconSize: 44,
              icon: Icon(
                isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                color: Colors.white,
              ),
              onPressed: () {
                _showControlsTemporarily();
                if (isPlaying) {
                  playerCtrl.playbackController.engine.pause();
                } else {
                  playerCtrl.playbackController.engine.resume();
                }
              },
            ),
          ),

          // Bottom Bar (Fullscreen toggle, favorite)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Live badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fiber_manual_record_rounded,
                      color: Colors.white,
                      size: 8,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              Row(
                children: [
                  // Favorite button
                  IconButton(
                    icon: Icon(
                      channel.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: channel.isFavorite ? Colors.amber : Colors.white,
                      size: 20,
                    ),
                    onPressed: () {
                      _showControlsTemporarily();
                      widget.controller.toggleFavorite(channel);
                    },
                  ),

                  // Fullscreen toggle
                  IconButton(
                    icon: Icon(
                      widget.isFullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () {
                      if (widget.isFullscreen) {
                        widget.controller.exitFullscreen();
                      } else {
                        widget.controller.enterFullscreen();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedHeroBanner(BuildContext context, ColorScheme colorScheme) {
    final featured = widget.controller.featuredChannel.value;

    return Container(
      height: 190.0,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.large,
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.15),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          ],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.tv_rounded,
              size: 140,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'FREE LIVE TV',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No Provider Required',
                        style: AppTypography.getCaption(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  featured != null
                      ? featured.name
                      : 'Thousands of Free Global Channels',
                  style: AppTypography.getTitle(
                    color: colorScheme.onSurface,
                  ).copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  featured != null
                      ? '${featured.country} • Public Free Stream'
                      : 'Stream public channels directly from IPTV-org.',
                  style: AppTypography.getBody(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                if (featured != null)
                  TvFocusable(
                    onTap: () => widget.controller.openChannel(featured),
                    borderRadius: AppRadius.pill,
                    child: FilledButton.icon(
                      onPressed: () =>
                          widget.controller.openChannel(featured),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Watch Featured Channel'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                      ),
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
