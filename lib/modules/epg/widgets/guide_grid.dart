import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:stream_hub/modules/epg/models/epg_channel.dart';
import 'package:stream_hub/modules/epg/models/epg_program.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';

// Constants for EPG Grid
const double _kChannelWidth = 224.0;
const double _kRowHeight = 96.0;
const double _kPixelsPerMinute = 512.0 / 60.0; // 512px per hour

class GuideGrid extends StatefulWidget {
  final List<EPGChannel> channels;
  final List<EPGProgram> programs;
  final Map<String, List<EPGProgram>> channelProgramsMap;
  final VoidCallback? onChannelTap;
  final VoidCallback? onProgramTap;

  const GuideGrid({
    super.key,
    required this.channels,
    required this.programs,
    required this.channelProgramsMap,
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
    return Column(
      children: [
        _buildTimelineHeader(),
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
                  child: _buildProgramsGrid(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineHeader() {
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
              SizedBox(width: _kChannelWidth),
              Expanded(
                child: SingleChildScrollView(
                  controller: _headerScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(), // Driven by grid
                  child: Row(
                    children: List.generate(
                      12, // 12 hours for mockup
                      (index) {
                        final time = DateTime.now().add(Duration(hours: index));
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
                            "${time.hour.toString().padLeft(2, '0')}:00",
                            style: AppTypography.getLabel(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
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
          return Container(
            height: _kRowHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4.0),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Center(
                    child: channel.logoUrl != null && channel.logoUrl!.isNotEmpty
                        ? Image.network(channel.logoUrl!, width: 32, height: 32, errorBuilder: (_,_,_) => const Icon(Icons.tv))
                        : Text(
                            channel.title.isNotEmpty ? channel.title.substring(0, 1).toUpperCase() : 'C',
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
                      Text(
                        channel.title,
                        style: AppTypography.getTitle(color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'CH ${channel.id.hashCode % 1000}', // Mock channel number
                        style: AppTypography.getLabel(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgramsGrid() {
    // 12 hours timeline width = 12 * 512.0 = 6144.0
    // To ensure rows can scroll properly inside the ListView, give the ListView a fixed width equal to the timeline width.
    return SizedBox(
      width: 6144.0, 
      child: ListView.builder(
        controller: _programsVerticalController,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.channels.length,
        itemBuilder: (context, index) {
          final channel = widget.channels[index];
          final programs = widget.channelProgramsMap[channel.id] ?? [];
          return Container(
            height: _kRowHeight,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              children: programs.map((program) => _buildProgramCard(program)).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgramCard(EPGProgram program) {
    final duration = program.endTime.difference(program.startTime).inMinutes;
    final width = (duration * _kPixelsPerMinute).clamp(100.0, 3000.0);

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
      child: EPGProgramCard(
        program: program,
        onTap: widget.onProgramTap,
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
        scale: _isFocused ? 1.1 : 1.0, // 1.1x card zoom on focus as per Stitch design guidelines
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: widget.program.isLive
                ? AppColors.primaryContainer.withValues(alpha: _isFocused ? 0.4 : 0.2)
                : AppColors.surfaceVariant.withValues(alpha: _isFocused ? 0.5 : 0.3),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: _isFocused
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.05),
              width: _isFocused ? 2.0 : 1.0,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.5), // Neon glow
                      blurRadius: 20.0,
                      spreadRadius: -5.0,
                    )
                  ]
                : [],
          ),
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.program.title,
                style: AppTypography.getTitle(color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              AppSpacing.heightXS,
              Text(
                '${_formatTime(widget.program.startTime)} - ${_formatTime(widget.program.endTime)}',
                style: AppTypography.getLabel(color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final amPm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }
}