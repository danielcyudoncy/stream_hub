import 'package:flutter/material.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'tv_focusable.dart';

class GreetingHeader extends StatelessWidget {
  final String greeting;
  final String userName;
  final String? workspaceName;
  final VoidCallback? onProfileTap;

  const GreetingHeader({
    super.key,
    required this.greeting,
    required this.userName,
    this.workspaceName,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          TvFocusable(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(28.0),
            scale: 1.1,
            child: CircleAvatar(
              radius: 28.0,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                AppIcons.profile,
                color: colorScheme.onPrimaryContainer,
                size: 28.0,
              ),
            ),
          ),
          AppSpacing.widthMD,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: AppTypography.getCaption(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  userName,
                  style: AppTypography.getTitle(
                    color: colorScheme.onSurface,
                  ),
                ),
                if (workspaceName != null) ...[
                  AppSpacing.heightXXS,
                  Text(
                    workspaceName!,
                    style: AppTypography.getCaption(
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}