import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/helpers/platform_helper.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/media_item.dart';
import 'movie_hero_banner.dart';

class MovieHeroCarousel extends StatefulWidget {
  final List<MediaItem> movies;
  final Duration? Function(String movieId)? getResumePosition;
  final bool Function(String movieId)? isFavorite;
  final void Function(MediaItem movie) onWatch;
  final void Function(MediaItem movie) onDetails;
  final void Function(MediaItem movie)? onToggleFavorite;
  final Duration autoPlayInterval;

  const MovieHeroCarousel({
    super.key,
    required this.movies,
    this.getResumePosition,
    this.isFavorite,
    required this.onWatch,
    required this.onDetails,
    this.onToggleFavorite,
    this.autoPlayInterval = const Duration(seconds: 6),
  });

  @override
  State<MovieHeroCarousel> createState() => _MovieHeroCarouselState();
}

class _MovieHeroCarouselState extends State<MovieHeroCarousel> {
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
  void didUpdateWidget(covariant MovieHeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movies.length != widget.movies.length) {
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
    if (widget.movies.length <= 1) return;
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!mounted || !_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % widget.movies.length;
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
    if (widget.movies.isEmpty) {
      return const SizedBox.shrink();
    }

    if (widget.movies.length == 1) {
      final movie = widget.movies.first;
      return MovieHeroBanner(
        movie: movie,
        resumePosition: widget.getResumePosition?.call(movie.id),
        isFavorite: widget.isFavorite?.call(movie.id) ?? movie.favorite,
        onWatch: () => widget.onWatch(movie),
        onDetails: () => widget.onDetails(movie),
        onToggleFavorite: widget.onToggleFavorite != null
            ? () => widget.onToggleFavorite!(movie)
            : null,
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
                  itemCount: widget.movies.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final movie = widget.movies[index];
                    return MovieHeroBanner(
                      key: ValueKey(movie.id),
                      movie: movie,
                      resumePosition: widget.getResumePosition?.call(movie.id),
                      isFavorite:
                          widget.isFavorite?.call(movie.id) ?? movie.favorite,
                      onWatch: () => widget.onWatch(movie),
                      onDetails: () => widget.onDetails(movie),
                      onToggleFavorite: widget.onToggleFavorite != null
                          ? () => widget.onToggleFavorite!(movie)
                          : null,
                    );
                  },
                ),
              ),

              // Page Indicator Dots
              Positioned(
                right: AppSpacing.lg,
                bottom: isTv ? AppSpacing.xl : AppSpacing.md,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(widget.movies.length, (index) {
                    final isActive = index == _currentPage;
                    return GestureDetector(
                      onTap: () {
                        _restartAutoPlay();
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3.0),
                        height: 6.0,
                        width: isActive ? 22.0 : 6.0,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.35),
                          borderRadius: AppRadius.pill,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
