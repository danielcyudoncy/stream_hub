import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';

class ChannelPlaceholder extends StatelessWidget {
  final double iconSize;
  final double fontSize;

  const ChannelPlaceholder({
    super.key,
    this.iconSize = 30.0,
    this.fontSize = 11.0,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.live_tv_rounded,
              size: iconSize,
              color: colorScheme.primary.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 5.0),
            Text(
              'chamDTech',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
