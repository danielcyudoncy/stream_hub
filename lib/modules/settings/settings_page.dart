import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/media/enums/playback_engine_preference.dart';
import 'package:stream_hub/core/routes/app_routes.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/shared/widgets/app_card.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/section_header.dart';
import 'package:stream_hub/shared/widgets/settings_tile.dart';
import 'package:stream_hub/shared/dialogs/confirmation_dialog.dart';
import 'settings_controller.dart';

class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppScaffold(
      title: 'Settings',
      body: Obx(() {
        if (controller.isLoading.value &&
            controller.errorMessage.value.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _buildMediaSourcesSection(context, colorScheme),
            AppSpacing.heightXL,
            _buildAppearanceSection(context, colorScheme),
            AppSpacing.heightXL,
            _buildPlaybackSection(context, colorScheme),
            AppSpacing.heightXL,
            _buildDownloadsSection(context, colorScheme),
            AppSpacing.heightXL,
            _buildStorageSection(context, colorScheme),
            AppSpacing.heightXL,
            _buildNotificationsSection(context, colorScheme),
            AppSpacing.heightXL,
            _buildAccountSection(context, colorScheme),
            AppSpacing.heightXL,
            _buildPrivacySection(context, colorScheme),
            AppSpacing.heightXL,
            _buildAboutSection(context, colorScheme),
            AppSpacing.heightXL,
            _buildDeveloperSection(context, colorScheme),
            AppSpacing.heightXXL,
          ],
        );
      }),
    );
  }

  Widget _buildMediaSourcesSection(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Media Sources',
          subtitle: 'Manage your IPTV providers and streaming sources',
        ),
        AppSpacing.heightXS,
        AppCard(
          child: Column(
            children: [
              SettingsTile(
                title: 'Add Source',
                subtitle: 'Connect a new media source',
                leadingIcon: Icons.add_circle_outline,
                onTap: () => Get.toNamed('/provider-manager'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
              SettingsTile(
                title: 'M3U',
                subtitle: 'M3U playlist URL or file',
                leadingIcon: Icons.video_library_outlined,
                onTap: () => Get.toNamed('/provider-manager'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
              SettingsTile(
                title: 'Xtream Codes',
                subtitle: 'Xtream Codes API connection',
                leadingIcon: Icons.api_outlined,
                onTap: () => Get.toNamed('/provider-manager'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
              SettingsTile(
                title: 'Stalker Portal',
                subtitle: 'Stalker Portal (MAC) connection',
                leadingIcon: Icons.satellite_alt_outlined,
                onTap: () => Get.toNamed('/provider-manager'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
              SettingsTile(
                title: 'XMLTV',
                subtitle: 'XMLTV guide source',
                leadingIcon: Icons.public_outlined,
                onTap: () => Get.toNamed('/provider-manager'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
              SettingsTile(
                title: 'Plex',
                subtitle: 'Plex media server',
                leadingIcon: Icons.live_tv_outlined,
                onTap: () => Get.toNamed('/provider-manager'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
              SettingsTile(
                title: 'Jellyfin',
                subtitle: 'Jellyfin media server',
                leadingIcon: Icons.movie_outlined,
                onTap: () => Get.toNamed('/provider-manager'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
              SettingsTile(
                title: 'Emby',
                subtitle: 'Emby media server',
                leadingIcon: Icons.video_collection_outlined,
                onTap: () => Get.toNamed('/provider-manager'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadsSection(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Downloads',
          subtitle: 'Manage downloaded content',
        ),
        AppSpacing.heightXS,
        AppCard(
          child: Column(
            children: [
              SettingsTile(
                title: 'Download Manager',
                subtitle: 'View and manage your downloaded content',
                leadingIcon: Icons.download_outlined,
                onTap: () {},
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
              SettingsTile(
                title: 'Storage Usage',
                subtitle: 'Check download storage usage',
                leadingIcon: Icons.storage_outlined,
                onTap: () {},
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Appearance',
          subtitle: 'Customize the visual theme',
        ),
        AppSpacing.heightXS,
        AppCard(
          child: Column(
            children: [
              SettingsTile(
                title: 'Theme Mode',
                subtitle: _themeLabel(controller.themeMode.value),
                leadingIcon: Icons.brightness_6_outlined,
                onTap: () => _showThemePicker(context),
              ),
              SettingsTile(
                title: 'Language',
                subtitle: controller.language.value == 'en'
                    ? 'English'
                    : controller.language.value,
                leadingIcon: Icons.language_outlined,
                onTap: () => _showLanguagePicker(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Account',
          subtitle: 'Manage your account details',
        ),
        AppSpacing.heightXS,
        AppCard(
          child: Column(
            children: [
              SettingsTile(
                title: 'Edit Profile',
                subtitle: 'Change your display name and photo',
                leadingIcon: Icons.person_outline,
                onTap: () => Get.toNamed('/profile'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
              SettingsTile(
                title: 'Change Password',
                subtitle: 'Update your account password',
                leadingIcon: Icons.lock_outline,
                onTap: () => _showChangePasswordDialog(context),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
              SettingsTile(
                title: 'Sign Out',
                leadingIcon: Icons.logout,
                iconColor: colorScheme.error,
                onTap: () => _showSignOutDialog(context),
              ),
              SettingsTile(
                title: 'Delete Account',
                leadingIcon: Icons.delete_outline,
                iconColor: colorScheme.error,
                onTap: () => _showDeleteAccountDialog(context),
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStorageSection(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Storage',
          subtitle: 'Manage local data and cache',
        ),
        AppSpacing.heightXS,
        AppCard(
          child: Column(
            children: [
              SettingsTile(
                title: 'Clear Cache',
                subtitle: 'Delete cached logos, EPG, and temporary files',
                leadingIcon: Icons.cleaning_services_outlined,
                onTap: () => controller.clearCache(),
              ),
              SettingsTile(
                title: 'Optimize Storage',
                subtitle: 'Compact local database and remove orphaned data',
                leadingIcon: Icons.storage_outlined,
                onTap: () => _showOptimizeDialog(context),
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackSection(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Playback',
          subtitle: 'Video and audio settings',
        ),
        AppSpacing.heightXS,
        AppCard(
          child: Column(
            children: [
              Obx(
                () => SettingsTile(
                  title: 'Preferred Player',
                  subtitle: _playerLabel(controller.preferredPlayer.value),
                  leadingIcon: Icons.play_circle_outline,
                  onTap: () => _showPlayerPicker(context),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
              ),
              Obx(
                () => SwitchListTile(
                  title: Text(
                    'Autoplay Next Episode',
                    style: AppTypography.getBody(color: colorScheme.onSurface),
                  ),
                  subtitle: Text(
                    'Automatically countdown and play the next episode in a series',
                    style: AppTypography.getCaption(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: controller.autoplayNextEpisode.value,
                  onChanged: controller.toggleAutoplayNextEpisode,
                  secondary: const Icon(Icons.playlist_play),
                ),
              ),
              Obx(
                () => SwitchListTile(
                  title: Text(
                    'Auto-Skip Intro',
                    style: AppTypography.getBody(color: colorScheme.onSurface),
                  ),
                  subtitle: Text(
                    'Automatically skip episode intro when timestamp is available',
                    style: AppTypography.getCaption(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: controller.autoSkipIntro.value,
                  onChanged: controller.toggleAutoSkipIntro,
                  secondary: const Icon(Icons.fast_forward_outlined),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildNotificationsSection(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Notifications',
          subtitle: 'Manage push notifications',
        ),
        AppSpacing.heightXS,
        AppCard(
          child: SwitchListTile(
            title: Text(
              'Enable Notifications',
              style: AppTypography.getBody(color: colorScheme.onSurface),
            ),
            subtitle: Text(
              'Receive updates about your providers',
              style: AppTypography.getCaption(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            value: controller.notificationsEnabled.value,
            onChanged: (value) => controller.toggleNotifications(value),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySection(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Privacy',
          subtitle: 'Privacy and security settings',
        ),
        AppSpacing.heightXS,
        AppCard(
          child: Column(
            children: [
              SwitchListTile(
                title: Text(
                  'Parental Lock',
                  style: AppTypography.getBody(color: colorScheme.onSurface),
                ),
                subtitle: Text(
                  'Restrict access to certain content',
                  style: AppTypography.getCaption(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                value: controller.parentalLockEnabled.value,
                onChanged: (value) => controller.toggleParentalLock(value),
              ),
              SettingsTile(
                title: 'Privacy Policy',
                leadingIcon: Icons.privacy_tip_outlined,
                onTap: () => Get.toNamed('/privacy-policy'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
              SettingsTile(
                title: 'Terms of Service',
                leadingIcon: Icons.description_outlined,
                onTap: () => Get.toNamed('/terms-of-service'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'About',
          subtitle: 'Application information',
        ),
        AppSpacing.heightXS,
        AppCard(
          child: SettingsTile(
            title: 'About StreamHub Pro',
            subtitle: 'Version 1.0.0 (Build 1)',
            leadingIcon: Icons.info_outline,
            onTap: () => Get.toNamed('/about'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildDeveloperSection(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Developer',
          subtitle: 'Advanced options and diagnostics',
        ),
        AppSpacing.heightXS,
        AppCard(
          child: SettingsTile(
            title: 'Developer Tools',
            subtitle: 'Stream, provider and playback diagnostics',
            leadingIcon: Icons.bug_report_outlined,
            onTap: () => Get.toNamed(AppRoutes.developer),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
        ),
        AppSpacing.heightXS,
        AppCard(
          child: SettingsTile(
            title: 'Open Source Licenses',
            leadingIcon: Icons.code_outlined,
            onTap: () => Get.toNamed('/licenses'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
        ),
      ],
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      default:
        return 'System Default';
    }
  }

  String _playerLabel(PlaybackEnginePreference preference) {
    switch (preference) {
      case PlaybackEnginePreference.mediaKit:
        return 'MediaKit';
      case PlaybackEnginePreference.exoPlayer:
        return 'ExoPlayer';
      case PlaybackEnginePreference.nativeActivity:
        return 'Native Player';
      case PlaybackEnginePreference.vlc:
        return 'VLC';
      case PlaybackEnginePreference.auto:
        return 'Auto (Recommended)';
    }
  }

  String _playerDescription(PlaybackEnginePreference preference) {
    switch (preference) {
      case PlaybackEnginePreference.mediaKit:
        return 'Always use MediaKit. Best for VOD files.';
      case PlaybackEnginePreference.exoPlayer:
        return 'Always use ExoPlayer. Native Android player with SurfaceView '
            'rendering; fixes black video on some devices.';
      case PlaybackEnginePreference.nativeActivity:
        return 'Always use the fullscreen native Android player. Renders video '
            'outside Flutter, the most reliable option on low-end devices.';
      case PlaybackEnginePreference.vlc:
        return 'Always use VLC. Best for problematic live streams.';
      case PlaybackEnginePreference.auto:
        return 'Pick the best engine per stream. Uses the native player for '
            'problematic live streams.';
    }
  }

  void _showPlayerPicker(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Preferred Player',
                style: AppTypography.getHeadline(color: colorScheme.onSurface),
              ),
              AppSpacing.heightMD,
              RadioGroup<PlaybackEnginePreference>(
                groupValue: controller.preferredPlayer.value,
                onChanged: (value) {
                  if (value != null) {
                    controller.changePreferredPlayer(value);
                    Get.back();
                  }
                },
                child: Column(
                  children: PlaybackEnginePreference.values.map((preference) {
                    final selected =
                        controller.preferredPlayer.value == preference;
                    return InkWell(
                      onTap: () => controller.changePreferredPlayer(preference),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs,
                        ),
                        child: Row(
                          children: [
                            Radio<PlaybackEnginePreference>(value: preference),
                            AppSpacing.widthXS,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _playerLabel(preference),
                                    style: AppTypography.getBody(
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    _playerDescription(preference),
                                    style: AppTypography.getCaption(
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              Icon(Icons.check, color: colorScheme.primary),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showThemePicker(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Theme',
              style: AppTypography.getHeadline(color: colorScheme.onSurface),
            ),
            AppSpacing.heightMD,
            RadioGroup<ThemeMode>(
              groupValue: controller.themeMode.value,
              onChanged: (value) {
                if (value != null) {
                  controller.changeThemeMode(value);
                  Get.back();
                }
              },
              child: Column(
                children: ThemeMode.values
                    .map(
                      (mode) => InkWell(
                        onTap: () => controller.changeThemeMode(mode),
                        child: Row(
                          children: [
                            Radio<ThemeMode>(value: mode),
                            AppSpacing.widthXS,
                            Text(
                              _themeLabel(mode),
                              style: AppTypography.getBody(
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Language',
              style: AppTypography.getHeadline(color: colorScheme.onSurface),
            ),
            AppSpacing.heightMD,
            RadioGroup<String>(
              groupValue: controller.language.value,
              onChanged: (value) {
                if (value != null) {
                  controller.changeLanguage(value);
                  Get.back();
                }
              },
              child: const Column(
                children: [
                  Row(
                    children: [
                      Radio<String>(value: 'en'),
                      Text('English'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
        title: Text(
          'Change Password',
          style: AppTypography.getHeadline(color: colorScheme.onSurface),
        ),
        content: const Text(
          'Password change is managed through your authentication provider.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    Get.dialog(
      ConfirmationDialog(
        title: 'Sign Out',
        message: 'Are you sure you want to sign out?',
        confirmText: 'Sign Out',
        onConfirm: controller.logout,
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    Get.dialog(
      ConfirmationDialog(
        title: 'Delete Account',
        message:
            'This action cannot be undone. All your data will be permanently removed.',
        confirmText: 'Delete',
        isDestructive: true,
        onConfirm: () {
          Get.back();
          Get.snackbar(
            'Account Deletion',
            'Account deletion is not yet implemented in offline mode.',
            snackPosition: SnackPosition.BOTTOM,
          );
        },
      ),
    );
  }

  void _showOptimizeDialog(BuildContext context) {
    Get.snackbar(
      'Optimize Storage',
      'Storage optimization will be available in a future update.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
