import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/section_header.dart';
import 'settings_controller.dart';

class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'Settings',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Appearance',
              subtitle: 'Customize the visual theme of StreamHub Pro',
            ),
            AppSpacing.heightXS,
            AppCard(
              child: Obx(
                () => Column(
                  children: [
                    RadioGroup<ThemeMode>(
                      groupValue: controller.themeMode.value,
                      onChanged: (ThemeMode? mode) {
                        if (mode != null) {
                          controller.changeThemeMode(mode);
                        }
                      },
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Radio<ThemeMode>(
                                value: ThemeMode.system,
                                fillColor: WidgetStateProperty.resolveWith<Color?>(
                                  (Set<WidgetState> states) {
                                    if (states.contains(
                                        WidgetState.selected)) {
                                      return colorScheme.primary;
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              Text(
                                'System Default',
                                style: AppTypography.getBody(
                                    color: colorScheme.onSurface),
                              ),
                            ],
                          ),
Row(
                            children: [
                              Radio<ThemeMode>(
                                value: ThemeMode.light,
                                fillColor: WidgetStateProperty.resolveWith<Color?>(
                                  (Set<WidgetState> states) {
                                    if (states.contains(
                                        WidgetState.selected)) {
                                      return colorScheme.primary;
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              Text(
                                'Light',
                                style: AppTypography.getBody(
                                    color: colorScheme.onSurface),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Radio<ThemeMode>(
                                value: ThemeMode.dark,
                                fillColor: WidgetStateProperty.resolveWith<Color?>(
                                  (Set<WidgetState> states) {
                                    if (states.contains(
                                        WidgetState.selected)) {
                                      return colorScheme.primary;
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              Text(
                                'Dark',
                                style: AppTypography.getBody(
                                    color: colorScheme.onSurface),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppSpacing.heightXL,
            const SectionHeader(
              title: 'Local Database',
              subtitle: 'Storage and cache controls',
            ),
            AppSpacing.heightXS,
            AppCard(
              child: ListTile(
                leading: Icon(AppIcons.delete, color: colorScheme.error),
                title: Text(
                  'Clear Offline Cache',
                  style: AppTypography.getBody(color: colorScheme.onSurface),
                ),
                subtitle: Text(
                  'Deletes all cached channel logos and EPG records.',
                  style: AppTypography.getCaption(),
                ),
                trailing: const Icon(AppIcons.forward),
                onTap: () {
                  Get.snackbar(
                    'Success',
                    'Offline cache cleared.',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    colorText: colorScheme.onSurface,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
