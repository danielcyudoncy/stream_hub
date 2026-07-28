import 'package:flutter/material.dart';
import 'package:stream_hub/core/theme/app_typography.dart';

class SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool showDivider;

  const SettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget content = ListTile(
      leading: leadingIcon != null
          ? Icon(leadingIcon, color: iconColor ?? colorScheme.primary)
          : null,
      title: Text(title, style: AppTypography.getBody(color: colorScheme.onSurface)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: AppTypography.getCaption(color: colorScheme.onSurface.withValues(alpha: 0.6)))
          : null,
      trailing: trailing,
      onTap: onTap,
    );

    if (!showDivider) return content;

    return Column(
      children: [
        content,
        Divider(
          height: 1,
          thickness: 1,
          color: colorScheme.outline.withValues(alpha: 0.08),
          indent: leadingIcon != null ? 72 : 16,
          endIndent: 16,
        ),
      ],
    );
  }
}
