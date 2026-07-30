import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/theme/app_colors.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/core/utils/responsive_helper.dart';
import 'package:stream_hub/modules/epg/controllers/program_controller.dart';
import 'package:stream_hub/modules/epg/models/epg_program.dart';
import 'package:stream_hub/modules/epg/widgets/now_indicator.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/loading/loading_indicator.dart';
import 'package:stream_hub/shared/widgets/error_view.dart';
import 'package:stream_hub/shared/widgets/empty_view.dart';

class ProgramDetailsPage extends GetView<ProgramController> {
  const ProgramDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTV = ResponsiveHelper.isTV(context);

    return AppScaffold(
      title: 'Program Details',
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: LoadingIndicator(),
          );
        }

        if (controller.error.value.isNotEmpty) {
          return ErrorView(
            message: controller.error.value,
            onRetry: () => controller.loadProgram(
              Get.parameters['programId'] ?? '',
            ),
          );
        }

        final program = controller.selectedProgram.value;
        if (program == null) {
          return const EmptyView(
            title: 'Program Not Found',
            description: 'The requested program could not be found.',
          );
        }

        return _buildContent(context, colorScheme, program, isTV);
      }),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ColorScheme colorScheme,
    EPGProgram program,
    bool isTV,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (program.poster != null && program.poster!.isNotEmpty)
            ClipRRect(
borderRadius: AppRadius.large,
              child: Image.network(
                program.poster!,
                width: double.infinity,
                height: isTV ? 400 : 250,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _buildPlaceholder(context),
              ),
            ),
          if (program.poster == null || program.poster!.isEmpty)
            _buildPlaceholder(context),
          const SizedBox(height: AppSpacing.lg),
          Text(
            program.title,
            style: AppTypography.getDisplay(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (program.subtitle != null && program.subtitle!.isNotEmpty)
            Text(
              program.subtitle!,
              style: AppTypography.getBody(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          if (program.isLive) _buildLiveIndicator(colorScheme),
          if (!program.isLive && program.isCurrentlyPlaying)
            NowIndicator(
              program: program,
              progressPercent: program.progressPercent,
              remainingTime: program.remainingTime,
            ),
          const SizedBox(height: AppSpacing.md),
          _buildInfoRow(colorScheme, 'Start Time',
              program.startTime.toString().substring(0, 16)),
          _buildInfoRow(colorScheme, 'End Time',
              program.endTime.toString().substring(0, 16)),
          _buildInfoRow(
              colorScheme, 'Duration', '${program.duration.inMinutes} min'),
          if (program.channelId != null)
            _buildInfoRow(colorScheme, 'Channel', program.channelId!),
          if (program.episodeNum != null)
            _buildInfoRow(
                colorScheme, 'Episode', 'S${program.season ?? '?'}:E${program.episodeNum}'),
          if (program.episodeTitle != null && program.episodeTitle!.isNotEmpty)
            _buildInfoRow(colorScheme, 'Episode Title', program.episodeTitle!),
          if (program.rating != null)
            _buildInfoRow(
                colorScheme, 'Rating', '${program.rating} / 10'),
          if (program.genres.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Genres',
              style: AppTypography.getBody(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children:                        program.genres
                  .map(
                    (g) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: AppRadius.small,
                      ),
                      child: Text(
                        g,
                        style: AppTypography.getCaption(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (program.cast != null && program.cast!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Cast',
              style: AppTypography.getBody(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              program.cast!.join(', '),
              style: AppTypography.getBody(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (program.directors != null && program.directors!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Directors',
              style: AppTypography.getBody(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              program.directors!.join(', '),
              style: AppTypography.getBody(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (program.description != null && program.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Description',
              style: AppTypography.getBody(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              program.description!,
              style: AppTypography.getBody(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          _buildActions(context, colorScheme, program),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.large,
      ),
      child: Icon(
        Icons.live_tv_outlined,
        color: colorScheme.onSurfaceVariant,
        size: 64,
      ),
    );
  }

  Widget _buildLiveIndicator(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkError,
        borderRadius: AppRadius.small,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.live_tv, color: Colors.white, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'LIVE',
            style: AppTypography.getCaption(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    ColorScheme colorScheme,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTypography.getCaption(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.getBody(
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    ColorScheme colorScheme,
    EPGProgram program,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.favorite_border),
            label: const Text('Favorite'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.primary),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.alarm_add_outlined),
            label: const Text('Remind'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.secondary,
              side: BorderSide(color: colorScheme.secondary),
            ),
          ),
        ),
      ],
    );
  }
}