import 'package:flutter/material.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/tv_focusable.dart';

class HomeContentRail extends StatelessWidget {
  final String title;
  final Widget? leading;
  final List<MediaItem> items;
  final VoidCallback? onSeeAll;
  final double? cardHeight;
  final double? cardWidth;
  final Widget Function(BuildContext context, MediaItem item, int index) itemBuilder;

  const HomeContentRail({
    super.key,
    required this.title,
    this.leading,
    required this.items,
    this.onSeeAll,
    this.cardHeight,
    this.cardWidth,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTv = PlatformHelper.isTV;
    final width = MediaQuery.of(context).size.width;

    final defaultWidth = isTv
        ? 155.0
        : (width >= 1024
            ? 140.0
            : (width >= 600 ? 130.0 : 120.0));

    final effectiveCardWidth = cardWidth ?? defaultWidth;
    final effectiveHeight = cardHeight ?? (effectiveCardWidth * 1.48 + 44.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                AppSpacing.widthXS,
              ],
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.getTitle(
                    color: colorScheme.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (onSeeAll != null)
                TvFocusable(
                  onTap: onSeeAll,
                  borderRadius: AppRadius.pill,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'See All',
                          style: AppTypography.getCaption(
                            color: colorScheme.primary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        AppSpacing.widthXXS,
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11.0,
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Horizontal scrolling rail
        SizedBox(
          height: effectiveHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                width: effectiveCardWidth,
                margin: const EdgeInsets.only(right: AppSpacing.md),
                child: itemBuilder(context, item, index),
              );
            },
          ),
        ),
      ],
    );
  }
}
