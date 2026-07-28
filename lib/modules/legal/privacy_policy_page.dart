import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/section_header.dart';

class PrivacyPolicyPage extends GetView {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppScaffold(
      title: 'Privacy Policy',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Privacy Policy', subtitle: 'Last updated: July 2026'),
            AppSpacing.heightXS,
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Privacy Matters', style: AppTypography.getTitle(color: colorScheme.onSurface)),
                  AppSpacing.heightSM,
                  Text(
                    'StreamHub Pro respects your privacy. This application operates primarily offline and stores data locally on your device. '
                    'No personal data is transmitted to third-party servers without your explicit consent.',
                    style: AppTypography.getBody(color: colorScheme.onSurface.withValues(alpha: 0.8)),
                  ),
                  AppSpacing.heightMD,
                  Text('Data Collection', style: AppTypography.getTitle(color: colorScheme.onSurface)),
                  AppSpacing.heightXS,
                  Text(
                    'We collect minimal data necessary for the application to function. This includes provider configurations stored locally, '
                    'usage analytics (if enabled), and crash reports (if enabled).',
                    style: AppTypography.getBody(color: colorScheme.onSurface.withValues(alpha: 0.8)),
                  ),
                  AppSpacing.heightMD,
                  Text('Data Storage', style: AppTypography.getTitle(color: colorScheme.onSurface)),
                  AppSpacing.heightXS,
                  Text(
                    'All data is stored locally on your device using encrypted local storage. We do not upload your playlists, '
                    'watch history, or preferences to any cloud service unless you explicitly enable cloud sync.',
                    style: AppTypography.getBody(color: colorScheme.onSurface.withValues(alpha: 0.8)),
                  ),
                  AppSpacing.heightMD,
                  Text('Third-Party Services', style: AppTypography.getTitle(color: colorScheme.onSurface)),
                  AppSpacing.heightXS,
                  Text(
                    'The application may integrate with third-party services such as Firebase for authentication and analytics. '
                    'These services have their own privacy policies.',
                    style: AppTypography.getBody(color: colorScheme.onSurface.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}