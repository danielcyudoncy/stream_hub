import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/section_header.dart';

class AboutPage extends GetView {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'About',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
                  ),
                  AppSpacing.heightMD,
                  Text('StreamHub Pro', style: AppTypography.getHeadline(color: colorScheme.onSurface)),
                  AppSpacing.heightXS,
                  Text('Version 1.0.0 (Build 1)', style: AppTypography.getCaption(color: colorScheme.onSurface.withValues(alpha: 0.6))),
                ],
              ),
            ),
            AppSpacing.heightXL,
            const SectionHeader(title: 'App Information', subtitle: 'General application details'),
            AppSpacing.heightXS,
            AppCard(
              child: Column(
                children: [
                  _buildInfoRow(context, 'Application Name', 'StreamHub Pro'),
                  _buildInfoRow(context, 'Version', '1.0.0'),
                  _buildInfoRow(context, 'Build Number', '1'),
                  _buildInfoRow(context, 'Developer', 'StreamHub Pro Team'),
                  _buildInfoRow(context, 'License', 'Commercial'),
                  _buildInfoRow(context, 'Website', 'https://streamhub.pro'),
                ],
              ),
            ),
            AppSpacing.heightXL,
            const SectionHeader(title: 'Open Source Libraries', subtitle: 'Third-party dependencies'),
            AppSpacing.heightXS,
            AppCard(
              child: Column(
                children: [
                  _buildInfoRow(context, 'Flutter', 'BSD-3-Clause'),
                  _buildInfoRow(context, 'GetX', 'MIT'),
                  _buildInfoRow(context, 'Hive', 'Apache-2.0'),
                  _buildInfoRow(context, 'Firebase', 'Proprietary'),
                  _buildInfoRow(context, 'Google Sign-In', 'BSD-3-Clause'),
                ],
              ),
            ),
            AppSpacing.heightXL,
            Center(
              child: Text(
                'StreamHub Pro is a premium IPTV player. This application does not provide any IPTV content.',
                textAlign: TextAlign.center,
                style: AppTypography.getCaption(color: colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: AppTypography.getCaption(color: colorScheme.onSurface.withValues(alpha: 0.6)))),
          Expanded(child: Text(value, style: AppTypography.getBody(color: colorScheme.onSurface))),
        ],
      ),
    );
  }
}
