import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/media_item.dart';
import 'series_hero_section.dart';

class SeriesHeroCarousel extends StatefulWidget {
  final List<MediaItem> series;
  final void Function(MediaItem series) onWatch;
  final void Function(MediaItem series)? onDetails;
  final void Function(MediaItem series)? onToggleFavorite;
  final Duration autoPlayInterval;

  const SeriesHeroCarousel({
    super.key,
    required this.series,
    required this.onWatch,
    this.onDetails,
    this.onToggleFavorite,
    this.autoPlayInterval = const Duration(seconds: 6),
  });

  @override
  State<SeriesHeroCarousel> createState() => _SeriesHeroCarouselState();
}

class _SeriesHeroCarouselState extends State<SeriesHeroCarousel> {
  late final PageController _pageController;
  Timer? _autoPlayTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant SeriesHeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.series.length != widget.series.length) {
      _restartAutoPlay();
    }
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    if (widget.series.length <= 1) return;
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!mounted || !_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % widget.series.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  void _restartAutoPlay() {
    _autoPlayTimer?.cancel();
    _startAutoPlay();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.series.isEmpty) {
      return const SizedBox.shrink();
    }

    if (widget.series.length == 1) {
      final item = widget.series.first;
      return SeriesHeroSection(
        series: item,
        onWatch: () => widget.onWatch(item),
        onDetails: widget.onDetails != null ? () => widget.onDetails!(item) : null,
        onFavorite: widget.onToggleFavorite != null
            ? () => widget.onToggleFavorite!(item)
            : null,
        isFavorite: item.favorite,
      );
    }

    final isTv = PlatformHelper.isTV;
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = isTv
            ? 560.0
            : (width >= 1024
                ? (screenHeight * 0.65).clamp(500.0, 900.0)
                : (width >= 600 ? 380.0 : 330.0));

        return SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification) {
                    _restartAutoPlay();
                  }
                  return false;
                },
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.series.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final item = widget.series[index];
                    return SeriesHeroSection(
                      key: ValueKey(item.id),
                      series: item,
                      onWatch: () => widget.onWatch(item),
                      onDetails: widget.onDetails != null
                          ? () => widget.onDetails!(item)
                          : null,
                      onFavorite: widget.onToggleFavorite != null
                          ? () => widget.onToggleFavorite!(item)
                          : null,
                      isFavorite: item.favorite,
                    );
                  },
                ),
              ),

              // Page Indicator Dots
              Positioned(
                right: AppSpacing.lg,
                bottom: AppSpacing.md,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    widget.series.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentPage == index ? 20.0 : 6.0,
                      height: 6.0,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white38,
                        borderRadius: AppRadius.pill,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
