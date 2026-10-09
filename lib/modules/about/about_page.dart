import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/theme/app_colors.dart';
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
      showNavigation: false,
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
                      gradient: LinearGradient(colors: AppColors.primaryGradient),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
                  ),
                  AppSpacing.heightMD,
                  Text('StreamHub Pro', style: AppTypography.getHeadline(color: colorScheme.onSurface)),
                  AppSpacing.heightXS,
                  Builder(
                    builder: (context) {
                      final updateService = Get.isRegistered<AppUpdateService>() ? Get.find<AppUpdateService>() : null;
                      final version = updateService?.currentVersion.value ?? AppConstants.appVersion;
                      final build = updateService?.currentBuildNumber.value ?? AppConstants.appBuildNumber;
                      return Text(
                        'Version $version (Build $build)',
                        style: AppTypography.getCaption(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                      );
                    },
                  ),
                ],
              ),
            ),
            AppSpacing.heightXL,
            const SectionHeader(title: 'App Information', subtitle: 'General application details'),
            AppSpacing.heightXS,
            AppCard(
              child: Builder(
                builder: (context) {
                  final updateService = Get.isRegistered<AppUpdateService>() ? Get.find<AppUpdateService>() : null;
                  final version = updateService?.currentVersion.value ?? AppConstants.appVersion;
                  final build = (updateService?.currentBuildNumber.value ?? AppConstants.appBuildNumber).toString();
                  return Column(
                    children: [
                      _buildInfoRow(context, 'Application Name', AppConstants.appName),
                      _buildInfoRow(context, 'Version', version),
                      _buildInfoRow(context, 'Build Number', build),
                      _buildInfoRow(context, 'Developer', AppConstants.developerName),
                      _buildInfoRow(context, 'License', 'Commercial'),
                      _buildInfoRow(context, 'Website', AppConstants.appWebsite),
                    ],
                  );
                },
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
