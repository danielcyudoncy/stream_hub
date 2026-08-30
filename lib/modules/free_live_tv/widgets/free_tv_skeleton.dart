import 'package:flutter/material.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';

class FreeTvSkeleton extends StatefulWidget {
  const FreeTvSkeleton({super.key});

  @override
  State<FreeTvSkeleton> createState() => _FreeTvSkeletonState();
}

class _FreeTvSkeletonState extends State<FreeTvSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final shimmerColor = (isDark ? Colors.white : Colors.black)
            .withValues(alpha: _animation.value * 0.15);

        return Column(
          children: [
            // Top App Bar skeleton
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8.0,
                bottom: 8.0,
                left: AppSpacing.md,
                right: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 140,
                    height: 24,
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),

            // Top Hero / Player placeholder
            Container(
              height: 200.0,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: shimmerColor,
                borderRadius: AppRadius.large,
              ),
              child: Center(
                child: Icon(
                  Icons.tv_rounded,
                  size: 48,
                  color: shimmerColor,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Category Bar placeholder
            SizedBox(
              height: 40.0,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: 6,
                itemBuilder: (context, index) {
                  return Container(
                    width: index == 0 ? 100 : 80,
                    margin: const EdgeInsets.only(right: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      borderRadius: AppRadius.pill,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Channel Cards Grid placeholder
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 1.0,
                ),
                itemCount: 8,
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      borderRadius: AppRadius.medium,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
