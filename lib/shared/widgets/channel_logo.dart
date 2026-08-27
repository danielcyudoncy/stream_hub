import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/image_url_formatter.dart';
import '../../data/models/channel.dart';
import '../../data/models/media_item.dart';
import 'channel_placeholder.dart';

class ChannelLogo extends StatelessWidget {
  final MediaItem channel;
  final double size;
  final bool showLiveIndicator;

  const ChannelLogo({
    super.key,
    required this.channel,
    this.size = 48.0,
    this.showLiveIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLive = channel is Channel && (channel as Channel).isLive;
    final rawPoster = channel.poster ??
        channel.thumbnail ??
        channel.metadata['stream_icon'] ??
        channel.metadata['streamIcon'] ??
        channel.metadata['logo'];
    final poster = ImageUrlFormatter.format(rawPoster, item: channel);

    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: AppRadius.large,
            image: poster != null
                ? DecorationImage(
                    image: NetworkImage(poster),
                    fit: BoxFit.cover,
                    onError: (_, _) {},
                  )
                : null,
          ),
          child: poster == null
              ? ChannelPlaceholder(
                  iconSize: size * 0.35,
                  fontSize: (size * 0.16).clamp(8.0, 11.0),
                )
              : null,
        ),
        if (showLiveIndicator && isLive)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxs,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: AppColors.darkSuccess,
                borderRadius: AppRadius.pill,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6.0,
                    height: 6.0,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 3.0),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 8.0,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}