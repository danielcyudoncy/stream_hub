import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';

import '../controllers/live_tv_controller.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/media/enums/media_type.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/channel.dart';
import '../../../data/models/program.dart';
import '../../../shared/widgets/channel_logo.dart';
import '../../../shared/widgets/live_badge.dart';
import '../../../shared/widgets/program_banner.dart';
import '../../../shared/widgets/metadata_row.dart';
import '../../../shared/widgets/favorite_button.dart';
import '../../../shared/widgets/empty_library.dart';

class ChannelDetailsPage extends GetView<LiveTVController> {
  const ChannelDetailsPage({super.key});

  String get channelId => Get.parameters['channelId'] ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Obx(() {
        final channel = controller.channels.firstWhereOrNull(
          (c) => c.id == channelId,
        );

        if (channel == null) {
          return Center(
            child: EmptyLibrary(
              title: 'Channel Not Found',
              description: 'The requested channel could not be loaded.',
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            _buildSliverAppBar(context, colorScheme, channel),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroSection(context, colorScheme, channel),
                  _buildInfoSection(context, colorScheme, channel),
                  _buildCurrentProgramSection(context, colorScheme, channel),
                  _buildUpcomingProgramsSection(context, colorScheme, channel),
                  _buildMetadataSection(context, colorScheme, channel),
                  _buildActionButtons(context, colorScheme, channel),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSliverAppBar(
    BuildContext context,
    ColorScheme colorScheme,
    MediaItem channel,
  ) {
    final isChannel = channel is Channel;
    final isLive = isChannel && channel.isLive;

    return SliverAppBar(
      expandedHeight: 200.0,
      pinned: true,
      backgroundColor: colorScheme.surface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Get.back(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                colorScheme.surface,
                colorScheme.surface.withValues(alpha: 0.3),
                colorScheme.surface.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: Center(
            child: ChannelLogo(
              channel: channel,
              size: 100.0,
              showLiveIndicator: isLive,
            ),
          ),
        ),
      ),
      actions: [
        FavoriteButton(
          isFavorite: channel.favorite,
          onTap: () => controller.toggleFavorite(channel),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          icon: const Icon(Icons.share_outlined),
          onPressed: () {
            /* Placeholder for share */
          },
          tooltip: 'Share',
        ),
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }

  Widget _buildHeroSection(
    BuildContext context,
    ColorScheme colorScheme,
    MediaItem channel,
  ) {
    final isChannel = channel is Channel;
    final isLive = isChannel && channel.isLive;
    final channelNumber = isChannel ? channel.number : null;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  channel.title,
                  style: AppTypography.getHeadline(
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.heightXS,
          if (channelNumber != null)
            Text(
              'Channel $channelNumber',
              style: AppTypography.getBody(
                color: colorScheme.primary,
              ),
            ),
          AppSpacing.heightXS,
          Row(
            children: [
              if (isLive) const LiveBadge(),
              AppSpacing.widthXS,
              if (channel.language != null)
                Text(
                  channel.language!,
                  style: AppTypography.getCaption(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              if (channel.country != null) ...[
                Text(' · '),
                Text(
                  channel.country!,
                  style: AppTypography.getCaption(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context,
    ColorScheme colorScheme,
    MediaItem channel,
  ) {
    if (channel.description == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: AppRadius.medium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Description',
              style: AppTypography.getTitle(
                color: colorScheme.onSurface,
              ),
            ),
            AppSpacing.heightXS,
            Text(
              channel.description!,
              style: AppTypography.getBody(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentProgramSection(
    BuildContext context,
    ColorScheme colorScheme,
    MediaItem channel,
  ) {
    if (channel.subtitle == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Now Playing',
            style: AppTypography.getTitle(
              color: colorScheme.onSurface,
            ),
          ),
          AppSpacing.heightXS,
          ProgramBanner(
            program: Program(
              id: 'current-${channel.id}',
              providerId: channel.providerId,
              providerType: channel.providerType,
              mediaType: MediaType.program,
              title: channel.subtitle!,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              startTime: DateTime.now(),
              endTime: DateTime.now().add(const Duration(hours: 1)),
            ),
            showChannelName: true,
            channelName: channel.title,
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingProgramsSection(
    BuildContext context,
    ColorScheme colorScheme,
    MediaItem channel,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upcoming',
            style: AppTypography.getTitle(
              color: colorScheme.onSurface,
            ),
          ),
          AppSpacing.heightXS,
          const SizedBox(height: 80),
          const Text(
            'Program guide loading...',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          AppSpacing.heightMD,
        ],
      ),
    );
  }

  Widget _buildMetadataSection(
    BuildContext context,
    ColorScheme colorScheme,
    MediaItem channel,
  ) {
    final metadataItems = <MetadataItem>[
      MetadataItem(
        icon: Icons.network_check_outlined,
        value: channel.providerType.displayName,
      ),
      if (channel.language != null)
        MetadataItem(
          icon: Icons.language_outlined,
          value: channel.language!,
        ),
      if (channel.country != null)
        MetadataItem(
          icon: Icons.public_outlined,
          value: channel.country!,
        ),
      if (channel.metadata['resolution'] != null)
        MetadataItem(
          icon: Icons.hd_outlined,
          value: channel.metadata['resolution'] as String,
        ),
      if (channel.genres.isNotEmpty)
        MetadataItem(
          icon: Icons.category_outlined,
          value: channel.genres.join(', '),
        ),
    ];

    if (metadataItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details',
            style: AppTypography.getTitle(
              color: colorScheme.onSurface,
            ),
          ),
          AppSpacing.heightXS,
          MetadataRow(items: metadataItems, wrap: true),
          AppSpacing.heightMD,
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    ColorScheme colorScheme,
    MediaItem channel,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                /* Playback disabled - not yet available */
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play'),
              style: FilledButton.styleFrom(
                disabledBackgroundColor:
                    colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () {
              /* Share placeholder */
            },
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }
}
