import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:stream_hub/core/utils/title_formatter.dart';
import 'package:stream_hub/modules/epg/models/epg_channel.dart';
import 'package:stream_hub/modules/epg/models/epg_program.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

// Constants for EPG Grid
const double _kChannelWidth = 175.0; // Compact TV channel column matching Xfinity guide style
const double _kRowHeight = 64.0;
const double _kPixelsPerMinute = 512.0 / 60.0; // 512px per hour (256px per 30 mins)

class GuideGrid extends StatefulWidget {
  final List<EPGChannel> channels;
  final List<EPGProgram> programs;
  final Map<String, List<EPGProgram>> channelProgramsMap;
  final String? activePlayingChannelId;
  final ValueChanged<EPGChannel>? onChannelTap;
  final ValueChanged<EPGProgram>? onProgramTap;
  final VoidCallback? onMoveUp;

  const GuideGrid({
    super.key,
    required this.channels,
    required this.programs,
    required this.channelProgramsMap,
    this.activePlayingChannelId,
    this.onChannelTap,
    this.onProgramTap,
    this.onMoveUp,
  });

  @override
  State<GuideGrid> createState() => _GuideGridState();
}

class _GuideGridState extends State<GuideGrid> {
  late ScrollController _headerScrollController;
  late ScrollController _gridHorizontalController;
  late ScrollController _channelsVerticalController;
  late ScrollController _programsVerticalController;

  @override
  void initState() {
    super.initState();
    _headerScrollController = ScrollController();
    _gridHorizontalController = ScrollController();
    _channelsVerticalController = ScrollController();
    _programsVerticalController = ScrollController();

    _gridHorizontalController.addListener(() {
      if (_headerScrollController.hasClients && _gridHorizontalController.hasClients) {
        if (_headerScrollController.offset != _gridHorizontalController.offset) {
          _headerScrollController.jumpTo(_gridHorizontalController.offset);
        }
      }
    });

    _channelsVerticalController.addListener(() {
      if (_channelsVerticalController.hasClients && _programsVerticalController.hasClients) {
        if (_channelsVerticalController.offset != _programsVerticalController.offset) {
          _programsVerticalController.jumpTo(_channelsVerticalController.offset);
        }
      }
    });

    _programsVerticalController.addListener(() {
      if (_channelsVerticalController.hasClients && _programsVerticalController.hasClients) {
        if (_programsVerticalController.offset != _channelsVerticalController.offset) {
          _channelsVerticalController.jumpTo(_programsVerticalController.offset);
        }
      }
    });
  }

  @override
  void dispose() {
    _headerScrollController.dispose();
    _gridHorizontalController.dispose();
    _channelsVerticalController.dispose();
    _programsVerticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timelineStart = DateTime(now.year, now.month, now.day, now.hour);
    final nowMinutes = now.difference(timelineStart).inMinutes;
    final nowOffset = (nowMinutes * _kPixelsPerMinute).clamp(0.0, 6144.0);

    return Column(
      children: [
        _buildTimelineHeader(timelineStart, nowOffset),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChannelColumn(),
              Expanded(
                child: SingleChildScrollView(
                  controller: _gridHorizontalController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: _buildProgramsGrid(nowOffset),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineHeader(DateTime timelineStart, double nowOffset) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final todayString = 'TODAY ${DateFormat('M/d').format(now)}';

    return Container(
      height: 48.0,
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Row(
            children: [
              Container(
                width: _kChannelWidth,
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    todayString,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _headerScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(), // Driven by grid
                  child: SizedBox(
                    width: 6144.0,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Row(
                          children: List.generate(
                            24, // 24 half-hour intervals (12 hours)
                            (index) {
                              final slotTime = timelineStart.add(Duration(minutes: index * 30));
                              final slotEnd = slotTime.add(const Duration(minutes: 30));
                              final timeLabel = DateFormat('h:mma').format(slotTime).toLowerCase();
                              final isCurrentSlot = (now.isAfter(slotTime) ||
                                      now.isAtSameMomentAs(slotTime)) &&
                                  now.isBefore(slotEnd);

                              return Container(
                                width: 256.0, // 30-min block width
                                padding: const EdgeInsets.only(left: 12.0, top: 12.0, bottom: 8.0),
                                decoration: BoxDecoration(
                                  color: isCurrentSlot
                                      ? AppColors.primary.withValues(alpha: 0.18)
                                      : null,
                                  border: Border(
                                    left: BorderSide(
                                      color: colorScheme.outline.withValues(alpha: 0.1),
                                    ),
                                    top: isCurrentSlot
                                        ? const BorderSide(color: AppColors.primary, width: 2.5)
                                        : BorderSide.none,
                                  ),
                                ),
                                child: Text(
                                  timeLabel,
                                  style: TextStyle(
                                    color: isCurrentSlot
                                        ? AppColors.primary
                                        : colorScheme.onSurfaceVariant,
                                    fontSize: 12.0,
                                    fontWeight: isCurrentSlot ? FontWeight.bold : FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Real-time "NOW" Badge in Header
                        Positioned(
                          left: nowOffset - 20,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Text(
                              'NOW',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 9.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelColumn() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: _kChannelWidth,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          right: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 15.0,
            offset: Offset(5, 0),
          ),
        ],
      ),
      child: ListView.builder(
        controller: _channelsVerticalController,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.channels.length,
        itemBuilder: (context, index) {
          final channel = widget.channels[index];
          final formattedTitle = TitleFormatter.formatChannelTitle(channel.title);
          final isPlaying = widget.activePlayingChannelId == channel.id;
          final channelNum = (channel.number != null && channel.number!.isNotEmpty)
              ? channel.number!
              : '${index + 1}';

          return TvFocusable(
            regionId: 'live_channels',
            itemId: channel.id,
            itemIndex: index,
            focusColor: const Color(0xFFFFD54F),
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowUp &&
                  index == 0 &&
                  widget.onMoveUp != null) {
                widget.onMoveUp!();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            onTap: () => widget.onChannelTap?.call(channel),
            child: Container(
              height: _kRowHeight,
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: isPlaying ? AppColors.primary.withValues(alpha: 0.14) : null,
                border: Border(
                  bottom: BorderSide(
                    color: isPlaying
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.05),
                    width: isPlaying ? 1.5 : 1.0,
                  ),
                  left: isPlaying
                      ? const BorderSide(color: AppColors.primary, width: 3.5)
                      : BorderSide.none,
                ),
                boxShadow: isPlaying
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 10.0,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isPlaying
                          ? AppColors.primary.withValues(alpha: 0.25)
                          : AppColors.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(
                        color: isPlaying
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.12),
                        width: 1.0,
                      ),
                    ),
                    child: Center(
                      child: channel.logoUrl != null && channel.logoUrl!.isNotEmpty
                          ? Image.network(
                              channel.logoUrl!,
                              width: 26,
                              height: 26,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.tv, color: Colors.white70, size: 16),
                            )
                          : Text(
                              channel.title.isNotEmpty
                                  ? channel.title.substring(0, 1).toUpperCase()
                                  : 'TV',
                              style: AppTypography.getTitle(
                                color: AppColors.primary,
                              ).copyWith(fontSize: 13),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          channelNum,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                        ),
                        const SizedBox(height: 1.0),
                        Text(
                          formattedTitle,
                          style: TextStyle(
                            color: isPlaying ? AppColors.primary : colorScheme.onSurfaceVariant,
                            fontSize: 10.5,
                            fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<EPGProgram> _getProgramsForChannel(EPGChannel channel) {
    final channelPrograms = widget.channelProgramsMap[channel.id];
    if (channelPrograms != null && channelPrograms.isNotEmpty) {
      return channelPrograms;
    }

    final now = DateTime.now();
    final currentHour = DateTime(now.year, now.month, now.day, now.hour);
    final channelTitle = TitleFormatter.formatChannelTitle(channel.title);

    return [
      EPGProgram(
        id: 'p1_${channel.id}',
        channelId: channel.id,
        title: '$channelTitle Live',
        startTime: currentHour,
        endTime: currentHour.add(const Duration(hours: 1)),
        mediaType: MediaType.program,
        providerId: channel.providerId,
        providerType: channel.providerType,
        createdAt: now,
        updatedAt: now,
        description: 'Current live broadcast on $channelTitle',
      ),
      EPGProgram(
        id: 'p2_${channel.id}',
        channelId: channel.id,
        title: 'Prime Showcase',
        startTime: currentHour.add(const Duration(hours: 1)),
        endTime: currentHour.add(const Duration(hours: 2, minutes: 30)),
        mediaType: MediaType.program,
        providerId: channel.providerId,
        providerType: channel.providerType,
        createdAt: now,
        updatedAt: now,
        description: 'Upcoming scheduled broadcast',
      ),
      EPGProgram(
        id: 'p3_${channel.id}',
        channelId: channel.id,
        title: 'Night Edition',
        startTime: currentHour.add(const Duration(hours: 2, minutes: 30)),
        endTime: currentHour.add(const Duration(hours: 5)),
        mediaType: MediaType.program,
        providerId: channel.providerId,
        providerType: channel.providerType,
        createdAt: now,
        updatedAt: now,
        description: 'Late night programming',
      ),
    ];
  }

  Widget _buildProgramsGrid(double nowOffset) {
    // 12 hours timeline width = 12 * 512.0 = 6144.0
    return SizedBox(
      width: 6144.0,
      child: Stack(
        children: [
          ListView.builder(
            controller: _programsVerticalController,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.channels.length,
            itemBuilder: (context, index) {
              final channel = widget.channels[index];
              final programs = _getProgramsForChannel(channel);
              return Container(
                height: _kRowHeight,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: programs.map((program) => _buildProgramCard(program, channel)).toList(),
                  ),
                ),
              );
            },
          ),
          // Vertical Real-Time "NOW" Indicator Line across entire grid
          Positioned(
            left: nowOffset,
            top: 0,
            bottom: 0,
            child: Container(
              width: 2.5,
              decoration: BoxDecoration(
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.8),
                    blurRadius: 8.0,
                    spreadRadius: 1.0,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramCard(EPGProgram program, EPGChannel channel) {
    var duration = program.endTime.difference(program.startTime).inMinutes;
    if (duration <= 0) duration = 60;
    final width = (duration * _kPixelsPerMinute).clamp(140.0, 3000.0);

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 3.0),
      child: EPGProgramCard(
        program: program,
        channel: channel,
        onTap: widget.onProgramTap != null ? () => widget.onProgramTap!(program) : null,
      ),
    );
  }
}

class EPGProgramCard extends StatefulWidget {
  final EPGProgram program;
  final EPGChannel? channel;
  final VoidCallback? onTap;

  const EPGProgramCard({
    super.key,
    required this.program,
    this.channel,
    this.onTap,
  });

  @override
  State<EPGProgramCard> createState() => _EPGProgramCardState();
}

class _EPGProgramCardState extends State<EPGProgramCard> {
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();
  bool _hasFocus = false;

  @override
  void dispose() {
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
    super.dispose();
  }

  bool _shouldShowBelow(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return false;
    final globalOffset = renderBox.localToGlobal(Offset.zero);
    return globalOffset.dy < 240;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (overlayContext) {
        final showBelow = _shouldShowBelow(context);
        return CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: showBelow ? Alignment.bottomCenter : Alignment.topCenter,
          followerAnchor: showBelow ? Alignment.topCenter : Alignment.bottomCenter,
          offset: Offset(0, showBelow ? 6.0 : -6.0),
          child: _buildPopoverCard(context, showBelow: showBelow),
        );
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: TvFocusable(
          onTap: widget.onTap,
          focusColor: const Color(0xFFFFD54F), // Gold/yellow focus ring matching Xfinity
          scale: 1.0,
          borderRadius: BorderRadius.circular(4.0),
          onFocusChange: (focused) {
            if (_hasFocus == focused) return;
            setState(() {
              _hasFocus = focused;
            });
            if (focused) {
              _overlayController.show();
            } else {
              _overlayController.hide();
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: _hasFocus
                  ? const Color(0xFF262832)
                  : (widget.program.isLive
                      ? (isDark
                          ? AppColors.primaryContainer.withValues(alpha: 0.25)
                          : colorScheme.primary.withValues(alpha: 0.12))
                      : (isDark
                          ? AppColors.surfaceVariant.withValues(alpha: 0.3)
                          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6))),
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(
                color: _hasFocus
                    ? const Color(0xFFFFD54F)
                    : (widget.program.isLive
                        ? (isDark
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : colorScheme.primary.withValues(alpha: 0.4))
                        : colorScheme.outline.withValues(alpha: 0.08)),
                width: _hasFocus ? 2.0 : 1.0,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.program.title,
                        style: AppTypography.getTitle(
                          color: _hasFocus ? Colors.white : colorScheme.onSurface,
                        ).copyWith(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.program.isLive)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 8.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTimeRange(widget.program.startTime, widget.program.endTime),
                  style: AppTypography.getLabel(
                    color: _hasFocus ? Colors.white70 : colorScheme.onSurfaceVariant,
                  ).copyWith(
                    fontSize: 10.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopoverCard(BuildContext context, {required bool showBelow}) {
    final rating = widget.program.metadata['rating']?.toString() ??
        widget.program.metadata['content_rating']?.toString() ??
        'TV14';
    final channelName = widget.channel?.title.toUpperCase() ?? '';
    final channelNum = widget.channel?.number != null && widget.channel!.number!.isNotEmpty
        ? ' ${widget.channel!.number}'
        : '';
    final channelLine = '$channelName$channelNum'.trim();
    final description = widget.program.description ??
        widget.program.subtitle ??
        'Live broadcast on ${widget.channel?.title ?? 'Channel'}';

    final cardBody = Container(
      width: 290.0,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: const Color(0xFF181A20),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.white24, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 18.0,
            spreadRadius: 2.0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            widget.program.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5.0),
          // Time & Channel Info with Rating Badge
          Row(
            children: [
              Text(
                '${DateFormat('h:mm').format(widget.program.startTime)}-${DateFormat('h:mma').format(widget.program.endTime).toLowerCase()}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (channelLine.isNotEmpty) ...[
                const SizedBox(width: 6.0),
                Flexible(
                  child: Text(
                    channelLine,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3.0),
                  border: Border.all(color: Colors.white30, width: 0.8),
                ),
                child: Text(
                  rating,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          // Synopsis / Description
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11.0,
              height: 1.25,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showBelow)
            _PopoverArrow(
              pointingDown: false,
              color: const Color(0xFF181A20),
              borderColor: Colors.white24,
            ),
          cardBody,
          if (!showBelow)
            _PopoverArrow(
              pointingDown: true,
              color: const Color(0xFF181A20),
              borderColor: Colors.white24,
            ),
        ],
      ),
    );
  }

  String _formatTimeRange(DateTime start, DateTime end) {
    var displayEnd = end;
    if (displayEnd.isBefore(start) || displayEnd == start || displayEnd.difference(start).inMinutes < 10) {
      displayEnd = start.add(const Duration(hours: 1));
    }
    final format = DateFormat('h:mm a');
    return '${format.format(start)} - ${format.format(displayEnd)}';
  }
}

class _PopoverArrow extends StatelessWidget {
  final bool pointingDown;
  final Color color;
  final Color borderColor;

  const _PopoverArrow({
    required this.pointingDown,
    required this.color,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(16, 7),
      painter: _ArrowPainter(
        pointingDown: pointingDown,
        color: color,
        borderColor: borderColor,
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final bool pointingDown;
  final Color color;
  final Color borderColor;

  _ArrowPainter({
    required this.pointingDown,
    required this.color,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    if (pointingDown) {
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
      path.close();
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.close();
    }

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) =>
      oldDelegate.pointingDown != pointingDown ||
      oldDelegate.color != color ||
      oldDelegate.borderColor != borderColor;
}