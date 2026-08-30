import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
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
      actions: actions != null ? [...actions!, AppSpacing.widthXXS] : null,
      centerTitle: centerTitle,
      backgroundColor: Colors.transparent,
      elevation: 0.0,
      iconTheme: IconThemeData(color: colorScheme.onSurface),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
