import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';

class ContinueWatchingRow extends StatelessWidget {
  final List<dynamic> items;
  final double itemWidth;
  final Widget Function(BuildContext context, dynamic item, int index)
      itemBuilder;

  const ContinueWatchingRow({
    super.key,
    required this.items,
    this.itemWidth = 160.0,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemWidth * 0.75 + AppSpacing.md + AppSpacing.sm,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            width: itemWidth,
            margin: EdgeInsets.only(right: AppSpacing.md),
            child: itemBuilder(context, item, index),
          );
        },
      ),
    );
  }
}