import 'package:flutter/material.dart';
import 'package:stream_hub/modules/epg/models/epg_channel.dart';
import 'package:stream_hub/modules/epg/models/epg_program.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_radius.dart';

class GuideGrid extends StatelessWidget {
  final List<EPGChannel> channels;
  final List<EPGProgram> programs;
  final Map<String, List<EPGProgram>> channelProgramsMap;
  final double channelColumnWidth;
  final double programTileWidth;
  final VoidCallback? onChannelTap;
  final VoidCallback? onProgramTap;

  const GuideGrid({
    super.key,
    required this.channels,
    required this.programs,
    required this.channelProgramsMap,
    this.channelColumnWidth = 120,
    this.programTileWidth = 200,
    this.onChannelTap,
    this.onProgramTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: channelColumnWidth,
            child: _buildChannelColumn(context),
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: _buildTimeline(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelColumn(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        for (final channel in channels)
          GestureDetector(
            onTap: () => onChannelTap?.call(),
            child: Container(
              height: 80,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    channel.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTimeline(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final channel in channels)
          SizedBox(
            width: programTileWidth,
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.md),
                for (final program in (channelProgramsMap[channel.id] ?? []))
                  GestureDetector(
                    onTap: () => onProgramTap?.call(),
                    child: Container(
                      height: 60,
                      margin: const EdgeInsets.only(
                        bottom: AppSpacing.xxs,
                        left: AppSpacing.xs,
                        right: AppSpacing.xs,
                      ),
                      padding: const EdgeInsets.all(AppSpacing.xxs),
                      decoration: BoxDecoration(
                        color: program.isLive
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: AppRadius.small,
                        border: program.isLive
                            ? Border.all(
                                color: Colors.red,
                                width: 1,
                              )
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          program.title,
                          style: const TextStyle(
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}