import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/routes/app_routes.dart';
import 'package:stream_hub/core/theme/app_icons.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/shared/widgets/app_card.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/settings_tile.dart';
import 'package:stream_hub/shared/widgets/tv_focusable.dart';
import 'developer_controller.dart';

class DeveloperPage extends GetView<DeveloperController> {
  const DeveloperPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppScaffold(
      title: 'Developer Tools',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Obx(() {
              final enabled = controller.isDebugEnabled;
              return TvFocusable(
                borderRadius: BorderRadius.circular(12),
                scale: 1.01,
                child: SwitchListTile(
                  title: Text(
                    'Debug Mode',
                    style: AppTypography.getBody(color: colorScheme.onSurface),
                  ),
                  subtitle: Text(
                    'Enables verbose logging of stream resolution, negotiation '
                    'and playback events. For debugging only.',
                    style: AppTypography.getCaption(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  value: enabled,
                  onChanged: (value) => value
                      ? controller.debugMode.enableAll()
                      : controller.debugMode.disableAll(),
                ),
              );
            }),
          ),
          AppSpacing.heightXS,
          AppCard(
            child: Column(
              children: [
                SettingsTile(
                  title: 'Playback Test',
                  subtitle: 'Resolve, validate and negotiate a stream URL',
                  leadingIcon: AppIcons.play,
                  onTap: () => Get.toNamed(AppRoutes.playbackTest),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
                SettingsTile(
                  title: 'Provider Test',
                  subtitle: 'Detect provider kind and analyze capabilities',
                  leadingIcon: AppIcons.library,
                  onTap: () => Get.toNamed(AppRoutes.providerTest),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
                SettingsTile(
                  title: 'Stream Test',
                  subtitle: 'Run a stored media item through the pipeline',
                  leadingIcon: AppIcons.settings,
                  showDivider: false,
                  onTap: () => Get.toNamed(AppRoutes.streamTest),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
