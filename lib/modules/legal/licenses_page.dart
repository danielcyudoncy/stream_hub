import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/section_header.dart';

class LicensesPage extends GetView {
  const LicensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppScaffold(
      title: 'Open Source Licenses',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Open Source Licenses', subtitle: 'Third-party licenses and attributions'),
            AppSpacing.heightXS,
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Flutter', style: AppTypography.getTitle(color: colorScheme.onSurface)),
                  AppSpacing.heightXS,
                  Text(
                    'Copyright 2014 The Flutter Authors. All rights reserved.\n'
                    'Licensed under the BSD-3-Clause license.',
                    style: AppTypography.getBody(color: colorScheme.onSurface.withValues(alpha: 0.8)),
                  ),
                  AppSpacing.heightMD,
                  Text('GetX', style: AppTypography.getTitle(color: colorScheme.onSurface)),
                  AppSpacing.heightXS,
                  Text(
                    'Copyright 2019 Jonas Otter.\n'
                    'Licensed under the MIT license.',
                    style: AppTypography.getBody(color: colorScheme.onSurface.withValues(alpha: 0.8)),
                  ),
                  AppSpacing.heightMD,
                  Text('Hive', style: AppTypography.getTitle(color: colorScheme.onSurface)),
                  AppSpacing.heightXS,
                  Text(
                    'Copyright 2018 Simon Leier.\n'
                    'Licensed under the Apache-2.0 license.',
                    style: AppTypography.getBody(color: colorScheme.onSurface.withValues(alpha: 0.8)),
                  ),
                  AppSpacing.heightMD,
                  Text('Firebase', style: AppTypography.getTitle(color: colorScheme.onSurface)),
                  AppSpacing.heightXS,
                  Text(
                    'Copyright 2024 Google LLC.\n'
                    'Licensed under the proprietary Firebase terms.',
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