import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/media/enums/playback_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/title_formatter.dart';
import '../../../data/models/channel.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/channel_placeholder.dart';
import '../controllers/live_tv_controller.dart';

class LiveTvEmbeddedPlayer extends StatefulWidget {
  final LiveTVController controller;

  const LiveTvEmbeddedPlayer({
    super.key,
    required this.controller,
  });

  @override
  State<LiveTvEmbeddedPlayer> createState() => _LiveTvEmbeddedPlayerState();
}

class _LiveTvEmbeddedPlayerState extends State<LiveTvEmbeddedPlayer> {
  bool _controlsVisible = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _startControlsTimer();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
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

  @override
  void dispose() {
    _controlsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final activeChannel = widget.controller.activePlayingChannel.value;
      final playerCtrl = widget.controller.inlinePlayerController;

      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: AppRadius.large,
              border: Border.all(
                color: activeChannel != null
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: activeChannel != null
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16.0,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: AppRadius.large,
              child: activeChannel != null && playerCtrl != null
                  ? _buildActivePlayer(activeChannel, playerCtrl)
                  : _buildFeaturedHero(),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildActivePlayer(
    MediaItem channel,
    dynamic playerCtrl,
  ) {
    final channelNum = channel is Channel ? channel.number : null;
    final formattedTitle = TitleFormatter.formatChannelTitle(channel.title);
    final categoryName = channel.genres.isNotEmpty
        ? channel.genres.first
        : (channel.metadata['category_name'] as String? ?? 'Live TV');

    return GestureDetector(
      onTap: _toggleControls,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Video Surface Layer
          Obx(() {
            playerCtrl.playbackController.engine.engineKindRx.value;
            final adapter = playerCtrl.playbackController.engine.adapter;
            return ColoredBox(
              color: Colors.black,
              child: adapter.buildPlayerWidget(),
            );
          }),

          // 2. Buffering / Loading State Indicator
          Obx(() {
            final state =
                playerCtrl.playbackController.engine.stateRx.value as PlaybackState;
            if (state == PlaybackState.loading ||
                state == PlaybackState.buffering) {
              return Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 32.0,
                        height: 32.0,
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2.5,
                        ),
                      ),
                      AppSpacing.heightSM,
                      Text(
                        state == PlaybackState.loading
                            ? 'Connecting to live stream...'
                            : 'Buffering...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
                        size: 32.0,
                      ),
                      AppSpacing.heightXS,
                      const Text(
                        'Unable to load live stream',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.0,
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
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }),

          // 3. Top Gradient & Channel Info
          AnimatedOpacity(
            opacity: _controlsVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
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
                child: Row(
                  children: [
                    // Red Live Pulse
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.85),
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
                              fontSize: 9.0,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),

                    // Channel Number (if available)
                    if (channelNum != null && channelNum.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          channelNum,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10.0,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Category Tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 2.0,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: AppRadius.pill,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        categoryName.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6.0),

                    // Close/Stop Button
                    GestureDetector(
                      onTap: () => widget.controller.stopInlinePlayer(),
                      child: Container(
                        padding: const EdgeInsets.all(4.0),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 16.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Bottom Controls Overlay & Fullscreen Expand Button
          AnimatedOpacity(
            opacity: _controlsVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
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
                child: Row(
                  children: [
                    // Play/Pause Button
                    Obx(() {
                      final state = playerCtrl
                          .playbackController.engine.stateRx.value as PlaybackState;
                      final isPlaying = state == PlaybackState.playing;

                      return IconButton(
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 24.0,
                        ),
                        onPressed: () {
                          _startControlsTimer();
                          playerCtrl.togglePlayPause();
                        },
                      );
                    }),

                    // Program Subtitle or Info
                    Expanded(
                      child: Text(
                        channel.subtitle ??
                            (channel.genres.isNotEmpty
                                ? channel.genres.join(' • ')
                                : 'Live Broadcast'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Favorite Toggle
                    Obx(() {
                      final isFav = widget.controller.favorites
                              .any((f) => f.id == channel.id) ||
                          channel.favorite;

                      return IconButton(
                        icon: Icon(
                          isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFav ? Colors.redAccent : Colors.white70,
                          size: 20.0,
                        ),
                        onPressed: () {
                          _startControlsTimer();
                          widget.controller.toggleFavorite(channel);
                        },
                      );
                    }),

                    // Fullscreen Expand Button
                    Tooltip(
                      message: 'Expand to Fullscreen',
                      child: IconButton(
                        icon: const Icon(
                          Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 26.0,
                        ),
                        onPressed: () => widget.controller.expandToFullscreen(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedHero() {
    final featured = widget.controller.featuredChannel.value ??
        widget.controller.channels.firstOrNull;

    if (featured == null) {
      return Container(
        color: const Color(0xFF161A1D),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.tv_rounded,
              color: AppColors.primary,
              size: 38.0,
            ),
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

    return GestureDetector(
      onTap: () => widget.controller.openChannel(featured),
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
            top: AppSpacing.sm,
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
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 11.0,
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    categoryName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
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
              width: 54.0,
              height: 54.0,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.25),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary,
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    blurRadius: 18.0,
                    spreadRadius: 2.0,
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 34.0,
              ),
            ),
          ),

          // Bottom Channel Information
          Positioned(
            bottom: AppSpacing.sm,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formattedTitle,
                  style: AppTypography.getTitle(color: Colors.white).copyWith(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2.0),
                Text(
                  featured.subtitle ?? 'Tap to watch live stream in top player',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
