import 'package:cached_network_image/cached_network_image.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    final isLive = channel is Channel && (channel as Channel).isLive;
    final rawPoster = channel.poster ??
        channel.thumbnail ??
        channel.metadata['stream_icon'] ??
        channel.metadata['streamIcon'] ??
        channel.metadata['logo'];
    final poster = ImageUrlFormatter.format(rawPoster, item: channel);

    final placeholderWidget = ChannelPlaceholder(
      iconSize: size * 0.35,
      fontSize: (size * 0.16).clamp(8.0, 11.0),
    );

    return Stack(
      children: [
        ClipRRect(
          borderRadius: AppRadius.large,
          child: Container(
            width: size,
            height: size,
            color: colorScheme.surfaceContainerHighest,
            child: (poster != null && poster.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: poster,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    memCacheWidth: (size * 2).toInt(),
                    memCacheHeight: (size * 2).toInt(),
                    placeholder: (context, url) => placeholderWidget,
                    errorWidget: (context, url, error) => placeholderWidget,
                  )
                : placeholderWidget,
          ),
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