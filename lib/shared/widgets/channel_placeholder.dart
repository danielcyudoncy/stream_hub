import 'package:flutter/material.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        final isCompact = maxHeight.isFinite && maxHeight < 50.0;
        final effectiveIconSize = isCompact ? 15.0 : iconSize;
        final effectiveFontSize = isCompact ? 8.0 : fontSize;
        final effectiveSpacing = isCompact ? 1.5 : 4.0;

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.live_tv_rounded,
                  size: effectiveIconSize,
                  color: colorScheme.primary.withValues(alpha: 0.75),
                ),
                SizedBox(height: effectiveSpacing),
                Text(
                  'chamDTech',
                  style: TextStyle(
                    fontSize: effectiveFontSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
