import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;

  const AppAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppBar(
      titleSpacing: leading != null ? 0.0 : AppSpacing.sm,
      title: Text(
        title,
        maxLines: 1,
        softWrap: false,
        style: AppTypography.getTitle(color: colorScheme.onSurface).copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      leading: leading,
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
