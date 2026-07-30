import 'package:flutter/material.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_radius.dart';

class TimelineRuler extends StatelessWidget {
  final DateTime windowStart;
  final DateTime windowEnd;
  final double height;

  const TimelineRuler({
    super.key,
    required this.windowStart,
    required this.windowEnd,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) {
    final totalDuration = windowEnd.difference(windowStart);
    if (totalDuration.inHours <= 0) return const SizedBox.shrink();

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceVariant.withValues(alpha: 0.3),
        borderRadius: AppRadius.small,
      ),
      child: Row(
        children: _buildHourMarkers(),
      ),
    );
  }

  List<Widget> _buildHourMarkers() {
    final markers = <Widget>[];
    final totalHours = windowEnd.difference(windowStart).inHours;
    final now = DateTime.now();

    for (int i = 0; i <= totalHours; i++) {
      final hourTime = windowStart.add(Duration(hours: i));
      final isCurrent = hourTime.year == now.year &&
          hourTime.month == now.month &&
          hourTime.day == now.day &&
          hourTime.hour == now.hour;

      markers.add(
        Expanded(
          child: Container(
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Column(
              children: [
                Container(
                  width: 1,
                  height: 8,
                  color: isCurrent ? AppColors.darkError : AppColors.darkTextMuted,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${hourTime.hour.toString().padLeft(2, '0')}:00',
                  style: TextStyle(
                    color: isCurrent ? AppColors.darkError : AppColors.darkTextMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return markers;
  }
}