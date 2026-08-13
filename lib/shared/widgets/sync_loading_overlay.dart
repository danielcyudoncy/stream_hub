import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/sync_progress.dart';

class SyncLoadingOverlay extends StatelessWidget {
  final Stream<SyncProgress> progressStream;
  final String title;
  final String completedMessage;

  const SyncLoadingOverlay({
    super.key,
    required this.progressStream,
    this.title = 'Loading Playlists',
    this.completedMessage = 'Loading completed',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: AppRadius.large,
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.25),
                blurRadius: 24.0,
                spreadRadius: 4.0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: AppColors.primaryGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 32.0,
                  color: colorScheme.onPrimary,
                ),
              ),
              AppSpacing.heightLG,

              Text(
                title,
                style: AppTypography.getHeadline(color: colorScheme.onSurface),
                textAlign: TextAlign.center,
              ),
              AppSpacing.heightSM,

              StreamBuilder<SyncProgress>(
                stream: progressStream,
                initialData: const SyncProgress(completed: 0, total: 0),
                builder: (context, snapshot) {
                  final progress = snapshot.data;
                  final completed = progress?.completed ?? 0;
                  final total = progress?.total ?? 0;
                  final message = progress?.message ?? 'Loading...';
                  final fraction = progress?.fraction ?? 0.0;

                  return Column(
                    children: [
                      // Counter text
                      Text(
                        total > 0
                            ? '$message ($completed/$total)'
                            : message,
                        style: AppTypography.getCaption(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      AppSpacing.heightMD,

                      // Progress bar
                      ClipRRect(
                        borderRadius: AppRadius.pill,
                        child: LinearProgressIndicator(
                          value: total > 0 ? fraction : null,
                          minHeight: 6.0,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        ),
                      ),
                      AppSpacing.heightSM,

                      // Percentage
                      if (total > 0)
                        Text(
                          '${(fraction * 100).toInt()}%',
                          style: AppTypography.getCaption(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
