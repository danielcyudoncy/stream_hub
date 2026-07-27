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
      title: Text(
        title,
        style: AppTypography.getTitle(color: colorScheme.onSurface),
      ),
      leading: leading,
      actions: actions != null ? [...actions!, AppSpacing.widthXS] : null,
      centerTitle: centerTitle,
      backgroundColor: Colors.transparent,
      elevation: 0.0,
      iconTheme: IconThemeData(color: colorScheme.onSurface),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
