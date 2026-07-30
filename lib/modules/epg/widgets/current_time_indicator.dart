import 'package:flutter/material.dart';
import 'package:stream_hub/core/theme/app_colors.dart';

class CurrentTimeIndicator extends StatelessWidget {
  final DateTime currentTime;
  final DateTime windowStart;
  final DateTime windowEnd;
  final double width;

  const CurrentTimeIndicator({
    super.key,
    required this.currentTime,
    required this.windowStart,
    required this.windowEnd,
    this.width = 2,
  });

  @override
  Widget build(BuildContext context) {
    final totalDuration = windowEnd.difference(windowStart).inMilliseconds;
    if (totalDuration <= 0) return const SizedBox.shrink();
    final elapsed = currentTime.difference(windowStart).inMilliseconds;
    final percent = (elapsed / totalDuration).clamp(0.0, 1.0);

    return Positioned(
      left: percent * (MediaQuery.of(context).size.width - width),
      top: 0,
      bottom: 0,
      width: width,
      child: Container(
        color: AppColors.darkError,
        width: width,
      ),
    );
  }
}