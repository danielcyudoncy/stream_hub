import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_library.dart';
import '../../../shared/widgets/premium_media_card.dart';
import '../../../shared/widgets/tv_focusable.dart';

class MoviesCategoryPage extends StatelessWidget {
  const MoviesCategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>?;
    final title = args?['title'] as String? ?? 'Category';
    final items = args?['items'] as List<MediaItem>? ?? const <MediaItem>[];
    final isTv = PlatformHelper.isTV;

    return AppScaffold(
      title: title,
      actions: [
        TvFocusable(
          onTap: () => Get.toNamed(AppRoutes.search),
          borderRadius: AppRadius.medium,
          child: const IconButton(
            icon: Icon(AppIcons.search),
            onPressed: null,
            tooltip: 'Search',
          ),
        ),
      ],
      body: items.isEmpty
          ? const EmptyLibrary(
              icon: AppIcons.movies,
              title: 'No Movies',
              description: 'This category is currently empty.',
              actionLabel: null,
              onAction: null,
            )
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: isTv ? 200.0 : 170.0,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: 0.52,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = items[index];
                        return PremiumMediaCard(
                          item: item,
                          onTap: () {
                            Get.toNamed(AppRoutes.movieDetails, arguments: item);
                          },
                        );
                      },
                      childCount: items.length,
                    ),
                  ),
                ),
              ],
            ),
    );
  }


}
