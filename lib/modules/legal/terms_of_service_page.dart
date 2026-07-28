import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/section_header.dart';

class TermsOfServicePage extends GetView {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppScaffold(
      title: 'Terms of Service',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Terms of Service', subtitle: 'Last updated: July 2026'),
            AppSpacing.heightXS,
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Agreement to Terms', style: AppTypography.getTitle(color: colorScheme.onSurface)),
                  AppSpacing.heightXS,
                  Text(
                    'By using StreamHub Pro, you agree to these Terms of Service. If you do not agree, please do not use this application.',
                    style: AppTypography.getBody(color: colorScheme.onSurface.withValues(alpha: 0.8)),
                  ),
                  AppSpacing.heightMD,
                  Text('Use of Service', style: AppTypography.getTitle(color: colorScheme.onSurface)),
                  AppSpacing.heightXS,
                  Text(
                    'StreamHub Pro is a media player application. It does not provide, host, or distribute any media content. '
                    'Users are responsible for ensuring they have the right to access any content they play through the application.',
                    style: AppTypography.getBody(color: colorScheme.onSurface.withValues(alpha: 0.8)),
                  ),
                  AppSpacing.heightMD,
                  Text('Limitation of Liability', style: AppTypography.getTitle(color: colorScheme.onSurface)),
                  AppSpacing.heightXS,
                  Text(
                    'StreamHub Pro is provided as-is without warranty. We are not liable for any damages arising from the use of this application.',
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