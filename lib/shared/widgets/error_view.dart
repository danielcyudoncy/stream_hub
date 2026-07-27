import 'package:flutter/material.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'app_button.dart';

class ErrorView extends StatelessWidget {
  final String message;
  final String? title;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorView({
    super.key,
    required this.message,
    this.title,
    this.onRetry,
    this.icon = AppIcons.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64.0,
              color: colorScheme.error,
            ),
            AppSpacing.heightMD,
            Text(
              title ?? 'Something went wrong',
              style: AppTypography.getTitle(color: colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
            AppSpacing.heightXS,
            Text(
              message,
              style: AppTypography.getBody(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              AppSpacing.heightLG,
              AppButton(
                text: 'Retry',
                onPressed: onRetry,
                type: ButtonType.secondary,
                width: 120.0,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
