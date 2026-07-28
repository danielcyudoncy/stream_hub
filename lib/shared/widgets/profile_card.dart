import 'package:flutter/material.dart';
import 'package:stream_hub/core/theme/app_icons.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'app_card.dart';

class ProfileCard extends StatelessWidget {
  final String displayName;
  final String? photoUrl;
  final String email;
  final String? subtitle;
  final VoidCallback? onTap;

  const ProfileCard({
    super.key,
    required this.displayName,
    this.photoUrl,
    required this.email,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: photoUrl != null && photoUrl!.isNotEmpty
                  ? null
                  : colorScheme.primaryContainer,
              image: photoUrl != null && photoUrl!.isNotEmpty
                  ? DecorationImage(image: NetworkImage(photoUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: (photoUrl == null || photoUrl!.isEmpty)
                ? Icon(AppIcons.profile, size: 28, color: colorScheme.primary)
                : null,
          ),
          AppSpacing.widthMD,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: AppTypography.getTitle(color: colorScheme.onSurface)),
                AppSpacing.heightXXS,
                Text(
                  email,
                  style: AppTypography.getCaption(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                if (subtitle != null) ...[
                  AppSpacing.heightXXS,
                  Text(
                    subtitle!,
                    style: AppTypography.getCaption(color: colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null) Icon(Icons.arrow_forward_ios, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}
