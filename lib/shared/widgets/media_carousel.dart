import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';

class MediaCarousel extends StatelessWidget {
  final List<dynamic> items;
  final double itemWidth;
  final double aspectRatio;
  final Widget Function(BuildContext context, dynamic item, int index)
      itemBuilder;
  final EdgeInsetsGeometry? padding;

  const MediaCarousel({
    super.key,
    required this.items,
    this.itemWidth = 160.0,
    this.aspectRatio = 0.75,
    required this.itemBuilder,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: SizedBox(
        height: itemWidth * aspectRatio + AppSpacing.md + AppSpacing.sm,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          padding: EdgeInsets.only(right: AppSpacing.lg),
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              width: itemWidth,
              margin: EdgeInsets.only(right: AppSpacing.md),
              child: itemBuilder(context, item, index),
            );
          },
        ),
      ),
    );
  }
}