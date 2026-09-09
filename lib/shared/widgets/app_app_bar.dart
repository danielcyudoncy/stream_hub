import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/services/active_profile_service.dart';
import '../../modules/profiles/profile_controller.dart';
import '../../modules/profiles/profile_avatar_helper.dart';
import 'tv_focusable.dart';

class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool automaticallyImplyLeading;
  final bool showBackButton;
  final VoidCallback? onBack;

  const AppAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.automaticallyImplyLeading = true,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget? effectiveLeading = leading;
    if (effectiveLeading == null && showBackButton) {
      effectiveLeading = TvFocusable(
        scale: 1.0,
        borderRadius: BorderRadius.circular(8),
        child: IconButton(
          icon: const Icon(AppIcons.back),
          tooltip: 'Back',
          onPressed: onBack ??
              () {
                if (Navigator.canPop(context)) {
                  Get.back();
                } else {
                  Get.offAllNamed(AppRoutes.home);
                }
              },
        ),
      );
    }

    final hasLeading = effectiveLeading != null;

    // Build profile avatar action — reactive, zero-cost when no controller.
    final profileAction = _ProfileAvatarButton(colorScheme: colorScheme);

    final effectiveActions = [
      ...?actions,
      profileAction,
      AppSpacing.widthXXS,
    ];

    return AppBar(
      titleSpacing: hasLeading ? 0.0 : AppSpacing.sm,
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: centerTitle ? Alignment.center : Alignment.centerLeft,
        child: Text(
          title,
          maxLines: 1,
          style: AppTypography.getTitle(color: colorScheme.onSurface).copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      leading: effectiveLeading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: effectiveActions,
      centerTitle: centerTitle,
      backgroundColor: Colors.transparent,
      elevation: 0.0,
      iconTheme: IconThemeData(color: colorScheme.onSurface),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// ─── Profile avatar button ────────────────────────────────────────────────

/// Shows the active profile's avatar in the app bar.
/// Tapping navigates to the profile page.
/// Uses Obx so it reacts instantly to profile switches without rebuilding
/// the full app bar.
class _ProfileAvatarButton extends StatelessWidget {
  final ColorScheme colorScheme;
  const _ProfileAvatarButton({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    // If ActiveProfileService is not yet registered, show a generic icon.
    if (!Get.isRegistered<ActiveProfileService>()) {
      return _genericButton(context);
    }

    return Obx(() {
      // Trigger rebuild when the active profile changes.
      Get.find<ActiveProfileService>().profileId.value;

      if (!Get.isRegistered<ProfileController>()) {
        return _genericButton(context);
      }
      final ctrl = Get.find<ProfileController>();
      final profile = ctrl.activeProfile.value;

      final idx = avatarIndexForProfile(profile);
      final preset = kAvatarPresets[idx];

      return TvFocusable(
        scale: 1.08,
        borderRadius: BorderRadius.circular(20),
        onTap: () => Get.toNamed(AppRoutes.profile),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Tooltip(
            message: profile?.displayName ?? 'Profile',
            child: CircleAvatar(
              radius: 16,
              backgroundColor: preset.color,
              child: Icon(preset.icon, color: Colors.white, size: 14),
            ),
          ),
        ),
      );
    });
  }

  Widget _genericButton(BuildContext context) {
    return TvFocusable(
      scale: 1.08,
      borderRadius: BorderRadius.circular(20),
      onTap: () => Get.toNamed(AppRoutes.profile),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Tooltip(
          message: 'Profile',
          child: CircleAvatar(
            radius: 16,
            child: Icon(Icons.person_rounded, size: 14),
          ),
        ),
      ),
    );
  }
}
