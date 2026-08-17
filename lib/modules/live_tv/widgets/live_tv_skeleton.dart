import 'package:flutter/material.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive_helper.dart';

class LiveTvSkeleton extends StatefulWidget {
  const LiveTvSkeleton({super.key});

  @override
  State<LiveTvSkeleton> createState() => _LiveTvSkeletonState();
}

class _LiveTvSkeletonState extends State<LiveTvSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTV = ResponsiveHelper.isTV(context);
    final crossAxisCount = isTV
        ? 5
        : (ResponsiveHelper.isDesktop(context)
            ? 4
            : (ResponsiveHelper.isTablet(context) ? 3 : 2));

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final opacity = _animation.value;
        final baseColor = colorScheme.surfaceContainerHighest.withValues(alpha: opacity);

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Hero card skeleton
            Container(
              height: isTV ? 220.0 : 180.0,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: AppRadius.large,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Search bar skeleton
            Container(
              height: 46.0,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: AppRadius.pill,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Category chips skeleton
            Row(
              children: List.generate(
                4,
                (index) => Container(
                  width: 90.0,
                  height: 36.0,
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: AppRadius.pill,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Grid cards skeleton
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: isTV ? 0.7 : 0.8,
              ),
              itemCount: crossAxisCount * 2,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: AppRadius.medium,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
