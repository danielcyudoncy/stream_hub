import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/media_item.dart';

class MediaSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<MediaItem> items;
  final Widget? emptyWidget;
  final Widget? trailing;
  final VoidCallback? onSeeAll;
  final Widget Function(BuildContext context, MediaItem item, int index)
  itemBuilder;

  const MediaSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    this.emptyWidget,
    this.trailing,
    this.onSeeAll,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return emptyWidget ?? const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.getTitle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      AppSpacing.heightXXS,
                      Text(
                        subtitle!,
                        style: AppTypography.getCaption(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onSeeAll != null)
                TextButton(onPressed: onSeeAll, child: const Text('See All')),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
        ),
        SizedBox(
          height: 205,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: items.length,
            separatorBuilder: (context, index) => AppSpacing.widthSM,
            itemBuilder: (context, index) =>
                itemBuilder(context, items[index], index),
          ),
        ),
      ],
    );
  }
}
