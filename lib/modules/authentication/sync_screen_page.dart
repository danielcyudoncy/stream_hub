// modules/authentication/sync_screen_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/routes/app_routes.dart';
import 'auth_controller.dart';

class SyncScreenPage extends StatefulWidget {
  const SyncScreenPage({super.key});

  @override
  State<SyncScreenPage> createState() => _SyncScreenPageState();
}

class _SyncScreenPageState extends State<SyncScreenPage> {
  final AuthController controller = Get.find<AuthController>();
  bool _hasStartedSync = false;

  @override
  Widget build(BuildContext context) {
    if (!_hasStartedSync) {
      _hasStartedSync = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startSyncAndNavigate();
      });
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo or icon
              const Icon(Icons.tv, size: 80, color: Colors.blue),
              const SizedBox(height: 32),
              // Sync status title
              Text(
                'Syncing Your Playlists',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Status message
              Obx(
                () => Text(
                  controller.syncStatus.value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 48),
              // Progress bar
              Obx(
                () => Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: controller.syncProgress.value,
                        minHeight: 12,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Percentage text
                    Text(
                      '${(controller.syncProgress.value * 100).toStringAsFixed(0)}% Complete',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    // Sources counter
                    Text(
                      '${controller.syncedSources.value} of ${controller.totalSources.value} sources synced',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              // Warning text
              Text(
                'Please wait while we sync your playlists. This screen will automatically close when complete.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startSyncAndNavigate() async {
    await controller.triggerAutomaticPlaylistSync();

    if (Get.currentRoute != AppRoutes.syncScreen) {
      return;
    }

    await Future.delayed(const Duration(milliseconds: 1500));

    if (Get.currentRoute == AppRoutes.syncScreen) {
      Get.offAllNamed(AppRoutes.home);
    }
  }
}
