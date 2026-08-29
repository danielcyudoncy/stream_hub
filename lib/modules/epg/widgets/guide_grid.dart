import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stream_hub/core/utils/title_formatter.dart';
import 'package:stream_hub/modules/epg/models/epg_channel.dart';
import 'package:stream_hub/modules/epg/models/epg_program.dart';
import 'package:stream_hub/core/media/enums/media_type.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';

// Constants for EPG Grid
const double _kChannelWidth = 290.0; // Increased width so full channel names are shown
const double _kRowHeight = 90.0;
const double _kPixelsPerMinute = 512.0 / 60.0; // 512px per hour

class GuideGrid extends StatefulWidget {
  final List<EPGChannel> channels;
  final List<EPGProgram> programs;
  final Map<String, List<EPGProgram>> channelProgramsMap;
  final String? activePlayingChannelId;
  final ValueChanged<EPGChannel>? onChannelTap;
  final ValueChanged<EPGProgram>? onProgramTap;

  const GuideGrid({
    super.key,
    required this.channels,
    required this.programs,
    required this.channelProgramsMap,
    this.activePlayingChannelId,
    this.onChannelTap,
    this.onProgramTap,
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
    return Container(
      height: 56.0,
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Row(
            children: [
              Container(
                width: _kChannelWidth,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                alignment: Alignment.centerLeft,
                child: Text(
                  'CHANNELS (${widget.channels.length})',
                  style: AppTypography.getCaption(
                    color: AppColors.textSecondary,
                  ).copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
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
                            12, // 12 hours timeline
                            (index) {
                              final hourTime = timelineStart.add(Duration(hours: index));
                              final timeLabel = DateFormat('h:mm a').format(hourTime);
                              return Container(
                                width: 512.0, // 1 hour width
                                padding: const EdgeInsets.only(left: 16.0, top: 16.0),
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                ),
                                child: Text(
                                  timeLabel,
                                  style: AppTypography.getLabel(
                                    color: AppColors.textSecondary,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                              );
                            },
                          ),
                        ),
                        // Real-time "NOW" Badge in Header
                        Positioned(
                          left: nowOffset - 24,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Text(
                              'NOW',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 9.5,
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
    return Container(
      width: _kChannelWidth,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
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
          return TvFocusable(
            onTap: () => widget.onChannelTap?.call(channel),
            child: Container(
              height: _kRowHeight,
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
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
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isPlaying
                          ? AppColors.primary.withValues(alpha: 0.25)
                          : AppColors.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: isPlaying
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.12),
                        width: isPlaying ? 1.5 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: channel.logoUrl != null && channel.logoUrl!.isNotEmpty
                          ? Image.network(
                              channel.logoUrl!,
                              width: 36,
                              height: 36,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.tv, color: Colors.white70, size: 22),
                            )
                          : Text(
                              channel.title.isNotEmpty
                                  ? channel.title.substring(0, 1).toUpperCase()
                                  : 'TV',
                              style: AppTypography.getTitle(
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                  ),
                  AppSpacing.widthMD,
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                formattedTitle,
                                style: AppTypography.getTitle(
                                  color: isPlaying ? AppColors.primary : AppColors.textPrimary,
                                ).copyWith(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                  shadows: isPlaying
                                      ? [
                                          Shadow(
                                            color: AppColors.primary.withValues(alpha: 0.8),
                                            blurRadius: 8.0,
                                          ),
                                        ]
                                      : null,
                                ),
                                maxLines: 2, // Displays full channel name across up to 2 lines
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isPlaying)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.graphic_eq_rounded,
                                      color: Colors.black,
                                      size: 9.0,
                                    ),
                                    SizedBox(width: 2.0),
                                    Text(
                                      'PLAYING',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (channel.number != null && channel.number!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              'CH ${channel.number}',
                              style: AppTypography.getLabel(color: AppColors.primary).copyWith(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
                    children: programs.map((program) => _buildProgramCard(program)).toList(),
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

  Widget _buildProgramCard(EPGProgram program) {
    var duration = program.endTime.difference(program.startTime).inMinutes;
    if (duration <= 0) duration = 60;
    final width = (duration * _kPixelsPerMinute).clamp(140.0, 3000.0);

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
      child: EPGProgramCard(
        program: program,
        onTap: widget.onProgramTap != null ? () => widget.onProgramTap!(program) : null,
      ),
    );
  }
}

class EPGProgramCard extends StatefulWidget {
  final EPGProgram program;
  final VoidCallback? onTap;

  const EPGProgramCard({
    super.key,
    required this.program,
    this.onTap,
  });

  @override
  State<EPGProgramCard> createState() => _EPGProgramCardState();
}

class _EPGProgramCardState extends State<EPGProgramCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onFocusChange: (focused) {
        setState(() {
          _isFocused = focused;
        });
      },
      borderRadius: BorderRadius.circular(8.0),
      child: AnimatedScale(
        scale: _isFocused ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: widget.program.isLive
                ? AppColors.primaryContainer.withValues(alpha: _isFocused ? 0.45 : 0.2)
                : AppColors.surfaceVariant.withValues(alpha: _isFocused ? 0.5 : 0.3),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: _isFocused
                  ? AppColors.primary
                  : (widget.program.isLive
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.06)),
              width: _isFocused ? 2.0 : 1.0,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      blurRadius: 16.0,
                    ),
                  ]
                : [],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.program.title,
                      style: AppTypography.getTitle(color: AppColors.textPrimary).copyWith(
                        fontSize: 13.5,
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
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _formatTimeRange(widget.program.startTime, widget.program.endTime),
                style: AppTypography.getLabel(color: AppColors.textSecondary).copyWith(
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
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