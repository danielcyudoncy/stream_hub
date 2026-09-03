import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/title_formatter.dart';
import '../../../data/models/channel.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/channel_placeholder.dart';
import '../../epg/controllers/guide_controller.dart';
import '../../epg/models/epg_program.dart';

class LiveTvChannelCard extends StatefulWidget {
  final MediaItem channel;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool isList;
  final bool showFavoriteButton;
  final bool showChannelNumber;
  final bool showHD;
  final bool isPlaying;

  const LiveTvChannelCard({
    super.key,
    required this.channel,
    this.onTap,
    this.onFavorite,
    this.isList = false,
    this.showFavoriteButton = true,
    this.showChannelNumber = true,
    this.showHD = true,
    this.isPlaying = false,
  });

  @override
  State<LiveTvChannelCard> createState() => _LiveTvChannelCardState();
}

class _LiveTvChannelCardState extends State<LiveTvChannelCard> {
  bool _isFocused = false;
  Timer? _longPressTimer;
  bool _longPressTriggered = false;

  FocusNode? _gridFocusNode;
  FocusNode? _listFocusNode;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _gridFocusNode?.dispose();
    _listFocusNode?.dispose();
    super.dispose();
  }

  KeyEventResult _handleCardKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.onFavorite == null) return KeyEventResult.ignored;

    final isSelect = event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA;

    if (!isSelect) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      if (_longPressTimer == null && !_longPressTriggered) {
        _longPressTimer = Timer(const Duration(milliseconds: 600), () {
          if (mounted) {
            _longPressTriggered = true;
            widget.onFavorite?.call();
          }
        });
      }
      return KeyEventResult.handled;
    } else if (event is KeyUpEvent) {
      final wasTriggered = _longPressTriggered;
      _longPressTimer?.cancel();
      _longPressTimer = null;
      _longPressTriggered = false;
      if (!wasTriggered) {
        widget.onTap?.call();
      }
      return KeyEventResult.handled;
    } else if (event is KeyRepeatEvent) {
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isList) {
      return _buildListTile(context);
    }
    return _buildGridCard(context);
  }

  Widget _buildGridCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isChannel = widget.channel is Channel;
    final channelNum = isChannel ? (widget.channel as Channel).number : null;
    final posterUrl = widget.channel.poster ?? widget.channel.thumbnail;
    final hasPoster = posterUrl != null && posterUrl.isNotEmpty;
    final resolution = widget.channel.metadata['resolution'] as String?;
    final isTV = PlatformHelper.isTV;

    final GuideController? guideController =
        Get.isRegistered<GuideController>() ? Get.find<GuideController>() : null;
    final now = DateTime.now();
    final String tvgId = widget.channel.metadata['tvgId']?.toString() ?? '';
    final String channelTitle = widget.channel.title;
    
    final EPGProgram? currentProgram = guideController?.programs
        .firstWhereOrNull((p) => 
          (p.channelId == tvgId || p.channelId == channelTitle || p.channelId == widget.channel.id) 
          && p.isCurrentlyPlaying
        );

    final double progress = currentProgram != null
        ? (now.difference(currentProgram.startTime).inSeconds /
                (currentProgram.endTime.difference(currentProgram.startTime).inSeconds > 0
                    ? currentProgram.endTime.difference(currentProgram.startTime).inSeconds
                    : 1))
            .clamp(0.0, 1.0)
        : (widget.isPlaying ? 0.45 : 0.0);

    final gridNode = _gridFocusNode ??= FocusNode();
    gridNode.onKeyEvent = _handleCardKeyEvent;

    return FocusableActionDetector(
      focusNode: gridNode,
      onFocusChange: (hasKeyboardFocus) {
        if (mounted && _isFocused != hasKeyboardFocus) {
          setState(() => _isFocused = hasKeyboardFocus);
          if (hasKeyboardFocus) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Scrollable.ensureVisible(
                  context,
                  alignment: 0.5,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                );
              }
            });
          }
        }
      },
      onShowFocusHighlight: (show) {
        if (mounted && _isFocused != show) {
          setState(() => _isFocused = show);
          if (show) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Scrollable.ensureVisible(
                  context,
                  alignment: 0.5,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                );
              }
            });
          }
        }
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<Intent>(
          onInvoke: (Intent intent) {
            widget.onTap?.call();
            return null;
          },
        ),
        ButtonActivateIntent: CallbackAction<Intent>(
          onInvoke: (Intent intent) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      mouseCursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onFavorite,
        child: AnimatedScale(
          scale: _isFocused ? (isTV ? 1.06 : 1.02) : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: widget.isPlaying
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : colorScheme.surface,
              borderRadius: AppRadius.medium,
              border: Border.all(
                color: widget.isPlaying
                    ? AppColors.primary
                    : (_isFocused
                        ? colorScheme.primary
                        : colorScheme.outline.withValues(alpha: 0.1)),
                width: widget.isPlaying ? 2.5 : (_isFocused ? 2.0 : 1.0),
              ),
              boxShadow: [
                if (widget.isPlaying || _isFocused)
                  BoxShadow(
                    color: AppColors.primary.withValues(
                      alpha: widget.isPlaying ? 0.45 : 0.35,
                    ),
                    blurRadius: widget.isPlaying ? 20.0 : 14.0,
                    spreadRadius: widget.isPlaying ? 2.0 : 1.0,
                    offset: const Offset(0, 4),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8.0,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Logo / Preview Area
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.isPlaying
                          ? AppColors.primary.withValues(alpha: 0.18)
                          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10.0),
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Centered properly scaled channel logo
                        if (hasPoster)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Image.network(
                              posterUrl,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildFallbackLogo(colorScheme),
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          _buildFallbackLogo(colorScheme),

                      // Top-Left: Channel number
                      if (widget.showChannelNumber && channelNum != null && channelNum.isNotEmpty)
                        Positioned(
                          top: AppSpacing.xxs,
                          left: AppSpacing.xxs,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5.0,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: AppRadius.small,
                            ),
                            child: Text(
                              channelNum,
                              style: TextStyle(
                                fontSize: 9.0,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),

                      // Bottom-Left: Resolution badge
                      if (widget.showHD && resolution != null && resolution.isNotEmpty)
                        Positioned(
                          bottom: AppSpacing.xxs,
                          left: AppSpacing.xxs,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5.0,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: AppRadius.small,
                            ),
                            child: Text(
                              resolution.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                      // Top-Right: Favorite Button
                      if (widget.showFavoriteButton)
                        Positioned(
                          top: AppSpacing.xxs,
                          right: AppSpacing.xxs,
                          child: ExcludeFocus(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.onFavorite,
                              child: Container(
                                padding: const EdgeInsets.all(5.0),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  widget.channel.favorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: widget.channel.favorite
                                      ? AppColors.darkError
                                      : Colors.white70,
                                  size: 16.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                  ),
                ),
              ),

              // Channel metadata section below image
              Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            TitleFormatter.formatChannelTitle(widget.channel.title),
                            style: AppTypography.getBody(
                              color: widget.isPlaying
                                  ? AppColors.primary
                                  : (_isFocused ? Colors.white : colorScheme.onSurface),
                              scale: 0.88,
                            ).copyWith(
                              fontWeight: FontWeight.bold,
                              shadows: widget.isPlaying
                                  ? [
                                      Shadow(
                                        color: AppColors.primary.withValues(alpha: 0.8),
                                        blurRadius: 10.0,
                                      ),
                                    ]
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.isPlaying)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4.0),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.6),
                                  blurRadius: 8.0,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.graphic_eq_rounded,
                                  color: Colors.black,
                                  size: 10.0,
                                ),
                                SizedBox(width: 3.0),
                                Text(
                                  'PLAYING',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Current Program or Genre / Subtitle
                    Text(
                      currentProgram?.title ??
                          (widget.channel.subtitle?.isNotEmpty == true
                              ? widget.channel.subtitle!
                              : (widget.channel.genres.isNotEmpty
                                  ? widget.channel.genres.first
                                  : 'Live Broadcast')),
                      style: AppTypography.getCaption(
                        color: _isFocused || widget.isPlaying ? AppColors.primary : AppColors.darkTextMuted,
                      ).copyWith(
                        fontSize: 10.5,
                        fontWeight: currentProgram != null || widget.isPlaying ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.isPlaying ? AppColors.primary : colorScheme.primary,
                        ),
                        minHeight: 2.5,
                      ),
                    ),
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

  Widget _buildListTile(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isChannel = widget.channel is Channel;
    final channelNum = isChannel ? (widget.channel as Channel).number : null;
    final posterUrl = widget.channel.poster ?? widget.channel.thumbnail;
    final hasPoster = posterUrl != null && posterUrl.isNotEmpty;
    final isTV = PlatformHelper.isTV;

    final GuideController? guideController =
        Get.isRegistered<GuideController>() ? Get.find<GuideController>() : null;
    final now = DateTime.now();
    final String tvgId = widget.channel.metadata['tvgId']?.toString() ?? '';
    final String channelTitle = widget.channel.title;
    
    final EPGProgram? currentProgram = guideController?.programs
        .firstWhereOrNull((p) => 
          (p.channelId == tvgId || p.channelId == channelTitle || p.channelId == widget.channel.id) 
          && p.isCurrentlyPlaying
        );

    final double progress = currentProgram != null
        ? (now.difference(currentProgram.startTime).inSeconds /
                (currentProgram.endTime.difference(currentProgram.startTime).inSeconds > 0
                    ? currentProgram.endTime.difference(currentProgram.startTime).inSeconds
                    : 1))
            .clamp(0.0, 1.0)
        : (widget.isPlaying ? 0.45 : 0.0);

    final String titleStr = currentProgram?.title ??
        (widget.channel.subtitle?.isNotEmpty == true
            ? widget.channel.subtitle!
            : (widget.channel.genres.isNotEmpty
                ? widget.channel.genres.first
                : 'Live Broadcast'));

    final String timeStr = currentProgram != null
        ? '${DateFormatter.formatTime(currentProgram.startTime)} - ${DateFormatter.formatTime(currentProgram.endTime)}'
        : '';

    final listNode = _listFocusNode ??= FocusNode();
    listNode.onKeyEvent = _handleCardKeyEvent;

    return FocusableActionDetector(
      focusNode: listNode,
      onFocusChange: (hasKeyboardFocus) {
        if (mounted && _isFocused != hasKeyboardFocus) {
          setState(() => _isFocused = hasKeyboardFocus);
          if (hasKeyboardFocus) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Scrollable.ensureVisible(
                  context,
                  alignment: 0.5,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                );
              }
            });
          }
        }
      },
      onShowFocusHighlight: (show) {
        if (mounted && _isFocused != show) {
          setState(() => _isFocused = show);
          if (show) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Scrollable.ensureVisible(
                  context,
                  alignment: 0.5,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                );
              }
            });
          }
        }
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<Intent>(
          onInvoke: (Intent intent) {
            widget.onTap?.call();
            return null;
          },
        ),
        ButtonActivateIntent: CallbackAction<Intent>(
          onInvoke: (Intent intent) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      mouseCursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onFavorite,
        child: AnimatedScale(
          scale: _isFocused ? (isTV ? 1.02 : 1.01) : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 6.0),
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
            decoration: BoxDecoration(
              // Glassmorphism Card with neon glow when playing
              color: widget.isPlaying
                  ? AppColors.primaryContainer.withValues(alpha: 0.25)
                  : const Color(0xCC121214),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(
                color: widget.isPlaying
                    ? AppColors.primary
                    : (_isFocused
                        ? colorScheme.primary
                        : Colors.white.withValues(alpha: 0.08)),
                width: widget.isPlaying ? 2.0 : (_isFocused ? 1.5 : 1.0),
              ),
              boxShadow: [
                if (widget.isPlaying || _isFocused)
                  BoxShadow(
                    color: AppColors.primary.withValues(
                      alpha: widget.isPlaying ? 0.4 : 0.25,
                    ),
                    blurRadius: widget.isPlaying ? 14.0 : 8.0,
                    spreadRadius: widget.isPlaying ? 1.5 : 0.0,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Compact Thumbnail container (52x38)
                Container(
                  width: 52.0,
                  height: 38.0,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasPoster
                      ? Image.network(
                          posterUrl,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildFallbackLogo(colorScheme),
                        )
                      : _buildFallbackLogo(colorScheme),
                ),
                const SizedBox(width: 10.0),

                // Channel Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Top Row: Channel Number • Name and Playing Indicator
                      Row(
                        children: [
                          if (widget.isPlaying) ...[
                            Container(
                              width: 6.0,
                              height: 6.0,
                              margin: const EdgeInsets.only(right: 5.0),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                          Expanded(
                            child: Text(
                              channelNum != null && channelNum.isNotEmpty
                                  ? '$channelNum • ${TitleFormatter.formatChannelTitle(widget.channel.title)}'
                                  : TitleFormatter.formatChannelTitle(widget.channel.title),
                              style: TextStyle(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w700,
                                color: widget.isPlaying
                                    ? AppColors.primary
                                    : (_isFocused ? colorScheme.primary : Colors.white),
                                shadows: widget.isPlaying
                                    ? [
                                        Shadow(
                                          color: AppColors.primary.withValues(alpha: 0.8),
                                          blurRadius: 10.0,
                                        ),
                                      ]
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (timeStr.isNotEmpty) ...[
                            const SizedBox(width: 6.0),
                            Text(
                              timeStr,
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: AppColors.darkTextSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2.0),

                      // Program Title / Subtitle
                      Text(
                        titleStr,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: AppColors.darkTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Progress Bar
                      if (currentProgram != null) ...[
                        const SizedBox(height: 4.0),
                        Container(
                          width: double.infinity,
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(1.5),
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primaryContainer,
                                    colorScheme.secondary,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Favorite Toggle Button
                if (widget.showFavoriteButton) ...[
                  const SizedBox(width: 6.0),
                  ExcludeFocus(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onFavorite,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          widget.channel.favorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: widget.channel.favorite
                              ? AppColors.darkError
                              : Colors.white38,
                          size: 18.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackLogo(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: ChannelPlaceholder(
        iconSize: widget.isList ? 18.0 : 26.0,
        fontSize: 9.0,
      ),
    );
  }
}
