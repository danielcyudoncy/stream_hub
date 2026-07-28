import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/shared/widgets/app_card.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/app_button.dart';
import 'package:stream_hub/shared/widgets/profile_card.dart';
import 'package:stream_hub/shared/widgets/section_header.dart';
import 'package:stream_hub/modules/authentication/models/user_model.dart';
import 'package:stream_hub/modules/settings/settings_controller.dart';
import 'profile_controller.dart';

class ProfilePage extends GetView<ProfileController> {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Profile',
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            SectionHeader(
              title: 'Your Profile',
              subtitle: 'Manage your personal information',
            ),
            AppSpacing.heightXS,
            ProfileCard(
              displayName: controller.displayName.value.isEmpty
                  ? 'Local User'
                  : controller.displayName.value,
              photoUrl: controller.photoUrl.value.isEmpty
                  ? null
                  : controller.photoUrl.value,
              email: controller.currentUser.value?.email ?? 'Offline Mode',
              subtitle: controller.currentUser.value != null
                  ? _authProviderLabel(controller.currentUser.value!.provider)
                  : 'No account linked',
              onTap: () {},
            ),
            AppSpacing.heightLG,
            SectionHeader(
              title: 'Edit Profile',
              subtitle: 'Update your display name and photo',
            ),
            AppSpacing.heightXS,
            AppCard(
              child: Column(
                children: [
                  _ProfileTextField(
                    label: 'Display Name',
                    hint: 'Enter your display name',
                    initialValue: controller.displayName.value,
                    onChanged: (value) => controller.displayName.value = value,
                  ),
                  AppSpacing.heightMD,
                  _ProfileTextField(
                    label: 'Photo URL',
                    hint: 'https://example.com/photo.jpg',
                    initialValue: controller.photoUrl.value,
                    onChanged: (value) => controller.photoUrl.value = value,
                  ),
                ],
              ),
            ),
            AppSpacing.heightLG,
            SectionHeader(
              title: 'Preferences',
              subtitle: 'Language and theme preferences',
            ),
            AppSpacing.heightXS,
            AppCard(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.language_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      'Language',
                      style: AppTypography.getBody(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      controller.activeProfile.value?.language ?? 'English',
                      style: AppTypography.getCaption(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showLanguagePicker(context),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.brightness_6_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      'Theme',
                      style: AppTypography.getBody(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      _themeLabel(
                        Get.find<SettingsController>().themeMode.value,
                      ),
                      style: AppTypography.getCaption(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Get.back(),
                  ),
                ],
              ),
            ),
            AppSpacing.heightLG,
            AppButton(
              text: 'Save Changes',
              onPressed: controller.saveProfileChanges,
            ),
            if (controller.errorMessage.value.isNotEmpty) ...[
              AppSpacing.heightMD,
              Text(
                controller.errorMessage.value,
                style: AppTypography.getBody(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        );
      }),
    );
  }

  String _authProviderLabel(AuthProvider provider) {
    switch (provider) {
      case AuthProvider.email:
        return 'Email & Password';
      case AuthProvider.google:
        return 'Google';
      case AuthProvider.anonymous:
        return 'Anonymous';
      case AuthProvider.unknown:
        return 'Unknown';
    }
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

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Language',
              style: AppTypography.getHeadline(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            AppSpacing.heightMD,
            RadioGroup<String>(
              groupValue: controller.activeProfile.value?.language ?? 'en',
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
}

class _ProfileTextField extends StatefulWidget {
  final String label;
  final String hint;
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _ProfileTextField({
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_ProfileTextField> createState() => _ProfileTextFieldState();
}

class _ProfileTextFieldState extends State<_ProfileTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _ProfileTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
      ),
      onChanged: widget.onChanged,
    );
  }
}
