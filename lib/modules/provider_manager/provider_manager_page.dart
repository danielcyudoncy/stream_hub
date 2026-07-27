import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/empty_view.dart';
import 'provider_manager_controller.dart';

class ProviderManagerPage extends GetView<ProviderManagerController> {
  const ProviderManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'Provider Manager',
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Get.snackbar(
            'Phase 2 Feature',
            'Adding playlist providers will be available in Phase 2.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: colorScheme.surfaceContainerHighest,
            colorText: colorScheme.onSurface,
          );
        },
        backgroundColor: colorScheme.primary,
        child: const Icon(AppIcons.add, color: Colors.white),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.providers.isEmpty) {
          return EmptyView(
            title: 'No Providers Connected',
            description:
                'Tap the "+" button below to connect your M3U URL, M3U File, or Xtream Codes API credentials.',
            icon: AppIcons.providers,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: controller.providers.length,
          itemBuilder: (context, index) {
            final provider = controller.providers[index];
            return Card(
              child: ListTile(
                leading: const Icon(AppIcons.providers),
                title: Text(provider.name ?? 'IPTV Playlist'),
                subtitle: Text(provider.type ?? 'M3U'),
                trailing: IconButton(
                  icon: const Icon(AppIcons.delete),
                  onPressed: () {},
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
