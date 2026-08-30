import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'tv_focusable.dart';

class FavoriteButton extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback? onTap;
  final double size;

  const FavoriteButton({
    super.key,
    required this.isFavorite,
    this.onTap,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TvFocusable(
      onTap: onTap,
      scale: 1.15,
      borderRadius: BorderRadius.circular(size),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isFavorite
              ? AppColors.darkError.withValues(alpha: 0.15)
              : colorScheme.surfaceContainerHighest,
        ),
        child: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          color: isFavorite ? AppColors.darkError : colorScheme.onSurfaceVariant,
          size: size,
        ),
      ),
    );
  }
}