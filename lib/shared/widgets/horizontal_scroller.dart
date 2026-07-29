import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';

class HorizontalScroller extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final List<Widget> children;
  final double itemWidth;
  final double itemHeight;
  final EdgeInsetsGeometry? padding;
  final bool showScrollbar;
  final double spacing;

  const HorizontalScroller({
    super.key,
    this.title,
    this.trailing,
    required this.children,
    this.itemWidth = 160.0,
    this.itemHeight = 200.0,
    this.padding,
    this.showScrollbar = true,
    this.spacing = AppSpacing.md,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null || trailing != null)
          Padding(
            padding: padding ??
                const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontSize: 16.0,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: padding ??
              EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
              ),
          child: Row(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                SizedBox(
                  width: itemWidth,
                  height: itemHeight,
                  child: children[i],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}