import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stream_hub/core/routes/app_routes.dart';
import 'package:stream_hub/core/theme/app_spacing.dart';
import 'package:stream_hub/core/theme/app_radius.dart';
import 'package:stream_hub/core/theme/app_typography.dart';
import 'package:stream_hub/core/utils/responsive_helper.dart';
import 'package:stream_hub/modules/epg/controllers/guide_controller.dart';
import 'package:stream_hub/modules/epg/widgets/program_card.dart';
import 'package:stream_hub/shared/widgets/app_scaffold.dart';
import 'package:stream_hub/shared/widgets/app_text_field.dart';
import 'package:stream_hub/shared/widgets/empty_view.dart';
import 'package:stream_hub/shared/loading/loading_indicator.dart';
import 'package:stream_hub/shared/widgets/error_view.dart';
import 'package:stream_hub/shared/widgets/filter_sheet.dart';

class GuideSearchPage extends GetView<GuideController> {
  const GuideSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTV = ResponsiveHelper.isTV(context);

    return AppScaffold(
      title: 'Guide Search',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppTextField(
              labelText: 'Search programs',
              hintText: 'Search programs, channels, cast, directors...',
              prefixIcon: Icons.search,
              onChanged: controller.setSearchQuery,
            ),
          ),
          _buildFilters(context),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: LoadingIndicator(),
                );
              }

              if (controller.error.value.isNotEmpty) {
                return ErrorView(
                  message: controller.error.value,
                  onRetry: controller.loadGuide,
                );
              }

              if (controller.filteredPrograms.isEmpty) {
                return const EmptyView(
                  title: 'No Results',
                  description:
                      'No programs match your search criteria. Try different keywords or filters.',
                );
              }

              return _buildResults(context, colorScheme, isTV);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          _filterChip(
            context,
            label: 'Favorites',
            isSelected: controller.showFavoritesOnly.value,
            onTap: () => controller.setFavoritesOnly(
              !controller.showFavoritesOnly.value,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (controller.categories.isNotEmpty)
            _filterChip(
              context,
              label: controller.selectedCategory.value.isEmpty
                  ? 'All Categories'
                  : controller.selectedCategory.value,
              isSelected: false,
              onTap: () => _showCategoryFilter(context),
            ),
          const SizedBox(width: AppSpacing.xs),
          if (controller.languages.isNotEmpty)
            _filterChip(
              context,
              label: controller.selectedLanguage.value.isEmpty
                  ? 'All Languages'
                  : controller.selectedLanguage.value,
              isSelected: false,
              onTap: () => _showLanguageFilter(context),
            ),
          const SizedBox(width: AppSpacing.xs),
          if (controller.countries.isNotEmpty)
            _filterChip(
              context,
              label: controller.selectedCountry.value.isEmpty
                  ? 'All Countries'
                  : controller.selectedCountry.value,
              isSelected: false,
              onTap: () => _showCountryFilter(context),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.pill,
        ),
        child: Text(
          label,
          style: AppTypography.getCaption(
            color: isSelected ? Colors.white : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  void _showCategoryFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => FilterSheet(
        sortField: 'category',
        filterType: 'category',
        filterProviderType: null,
        availableTypes: controller.categories,
        onSortChanged: (_) {},
        onFilterChanged: (value) {
          controller.setCategory(value);
          Navigator.pop(context);
        },
        onProviderTypeChanged: (_) {},
        onApply: () {},
        onReset: () {},
      ),
    );
  }

  void _showLanguageFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => FilterSheet(
        sortField: 'language',
        filterType: 'language',
        filterProviderType: null,
        availableTypes: controller.languages,
        onSortChanged: (_) {},
        onFilterChanged: (value) {
          controller.setLanguage(value);
          Navigator.pop(context);
        },
        onProviderTypeChanged: (_) {},
        onApply: () {},
        onReset: () {},
      ),
    );
  }

  void _showCountryFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => FilterSheet(
        sortField: 'country',
        filterType: 'country',
        filterProviderType: null,
        availableTypes: controller.countries,
        onSortChanged: (_) {},
        onFilterChanged: (value) {
          controller.setCountry(value);
          Navigator.pop(context);
        },
        onProviderTypeChanged: (_) {},
        onApply: () {},
        onReset: () {},
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    ColorScheme colorScheme,
    bool isTV,
  ) {
    if (isTV) {
      return GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.75,
        ),
        itemCount: controller.filteredPrograms.length,
        itemBuilder: (context, index) {
          final program = controller.filteredPrograms[index];
          return ProgramCard(
            program: program,
            onTap: () {
              Get.toNamed(
                AppRoutes.programDetails,
                parameters: {'programId': program.id},
              );
            },
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: controller.filteredPrograms.length,
      itemBuilder: (context, index) {
        final program = controller.filteredPrograms[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: ProgramCard(
            program: program,
            onTap: () {
              Get.toNamed(
                AppRoutes.programDetails,
                parameters: {'programId': program.id},
              );
            },
          ),
        );
      },
    );
  }
}