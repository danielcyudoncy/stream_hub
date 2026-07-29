import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/app_search_bar.dart';
import '../../../shared/widgets/channel_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/empty_library.dart';

class SearchPage extends GetView<FavoritesController> {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppSearchBar(
              hintText: 'Search channels, providers, categories...',
              onChanged: (query) {
                /* Search engine implementation coming soon */
              },
              onSubmitted: (query) {
                /* Search engine implementation coming soon */
              },
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    context,
                    'Recent Searches',
                    const [
                      'sports',
                      'news',
                      'live',
                    ],
                  ),
                  _buildSection(
                    context,
                    'Quick Filters',
                    const [
                      'HD Channels',
                      'Live Now',
                      'Favorites',
                      'Sports',
                      'News',
                      'Kids',
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<String> items,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSpacing.heightMD,
        Text(
          title,
          style: AppTypography.getTitle(
            color: colorScheme.onSurface,
          ),
        ),
        AppSpacing.heightXS,
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: items.map((item) {
            return GestureDetector(
              onTap: () {
                Get.toNamed(
                  '/live-tv',
                  parameters: {
                    'filter': item.toLowerCase().replaceAll(' ', '_'),
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999.0),
                ),
                child: Text(
                  item,
                  style: AppTypography.getCaption(
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}